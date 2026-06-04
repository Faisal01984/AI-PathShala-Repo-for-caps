
-- Allow principals to update lessons (already have SELECT/DELETE)
CREATE POLICY "Principals update any lesson"
ON public.lessons
FOR UPDATE
TO authenticated
USING (public.has_role(auth.uid(), 'principal'::public.app_role))
WITH CHECK (public.has_role(auth.uid(), 'principal'::public.app_role));

-- Recreate list_lessons_for_viewer to include teacher_name and support principals
DROP FUNCTION IF EXISTS public.list_lessons_for_viewer();
CREATE OR REPLACE FUNCTION public.list_lessons_for_viewer()
RETURNS TABLE(
  id uuid, teacher_id uuid, teacher_name text,
  title text, subject text, grade text, topic text,
  duration integer, objectives text, difficulty text, language text,
  target_grade text, created_at timestamptz, updated_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    l.id, l.teacher_id,
    COALESCE(p.full_name, u.email::text) AS teacher_name,
    l.title, l.subject, l.grade, l.topic,
    l.duration, l.objectives, l.difficulty, l.language,
    l.target_grade, l.created_at, l.updated_at
  FROM public.lessons l
  LEFT JOIN public.profiles p ON p.id = l.teacher_id
  LEFT JOIN auth.users u ON u.id = l.teacher_id
  WHERE
    public.has_role(auth.uid(), 'principal'::public.app_role)
    OR (
      public.has_role(auth.uid(), 'teacher'::public.app_role)
      AND l.teacher_id = auth.uid()
    )
    OR (
      NOT public.has_role(auth.uid(), 'teacher'::public.app_role)
      AND NOT public.has_role(auth.uid(), 'principal'::public.app_role)
      AND (
        l.target_grade = 'All'
        OR l.target_grade = public.get_assigned_grade(auth.uid())
        OR (l.target_grade = 'AI Class' AND public.is_special_class(auth.uid()))
      )
    )
  ORDER BY l.created_at DESC;
$$;

-- Allow principal to fetch full lesson content (mirror teacher access) for editing
CREATE OR REPLACE FUNCTION public.get_lesson_full(_lesson_id uuid)
RETURNS public.lessons
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT *
  FROM public.lessons
  WHERE id = _lesson_id
    AND (
      (teacher_id = auth.uid() AND public.has_role(auth.uid(), 'teacher'::public.app_role))
      OR public.has_role(auth.uid(), 'principal'::public.app_role)
    );
$$;

-- Allow get_lesson_for_viewer to accept principals
CREATE OR REPLACE FUNCTION public.get_lesson_for_viewer(_lesson_id uuid)
RETURNS public.lessons
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  row public.lessons;
  content jsonb;
  quiz jsonb;
  new_quiz jsonb := '[]'::jsonb;
  q jsonb;
  ws jsonb;
  viewer uuid := auth.uid();
  viewer_is_teacher boolean := public.has_role(auth.uid(), 'teacher'::public.app_role);
  viewer_is_principal boolean := public.has_role(auth.uid(), 'principal'::public.app_role);
BEGIN
  SELECT * INTO row FROM public.lessons WHERE id = _lesson_id;
  IF NOT FOUND THEN RETURN NULL; END IF;

  IF viewer IS NULL OR NOT (
    viewer_is_principal
    OR (viewer_is_teacher AND row.teacher_id = viewer)
    OR row.target_grade = 'All'
    OR row.target_grade = public.get_assigned_grade(viewer)
    OR (row.target_grade = 'AI Class' AND public.is_special_class(viewer))
  ) THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  -- Teacher owners and principals see full content
  IF viewer_is_principal OR (viewer_is_teacher AND row.teacher_id = viewer) THEN
    RETURN row;
  END IF;

  -- Students: strip answer keys
  content := coalesce(row.content, '{}'::jsonb);
  content := content - 'answerKey';

  quiz := content->'quiz';
  IF quiz IS NOT NULL AND jsonb_typeof(quiz) = 'array' THEN
    FOR q IN SELECT * FROM jsonb_array_elements(quiz) LOOP
      q := q - 'answerIndex' - 'expectedAnswer' - 'keywords' - 'explanation' - 'rubric';
      new_quiz := new_quiz || jsonb_build_array(q);
    END LOOP;
    content := jsonb_set(content, '{quiz}', new_quiz);
  END IF;

  ws := content->'worksheet';
  IF ws IS NOT NULL THEN
    IF ws ? 'fillInBlanks' AND jsonb_typeof(ws->'fillInBlanks') = 'array' THEN
      content := jsonb_set(content, '{worksheet,fillInBlanks}',
        coalesce((SELECT jsonb_agg(item - 'answer') FROM jsonb_array_elements(ws->'fillInBlanks') item), '[]'::jsonb));
    END IF;
    IF ws ? 'trueOrFalse' AND jsonb_typeof(ws->'trueOrFalse') = 'array' THEN
      content := jsonb_set(content, '{worksheet,trueOrFalse}',
        coalesce((SELECT jsonb_agg(item - 'answer') FROM jsonb_array_elements(ws->'trueOrFalse') item), '[]'::jsonb));
    END IF;
    IF ws ? 'shortAnswer' AND jsonb_typeof(ws->'shortAnswer') = 'array' THEN
      content := jsonb_set(content, '{worksheet,shortAnswer}',
        coalesce((SELECT jsonb_agg(item - 'answer') FROM jsonb_array_elements(ws->'shortAnswer') item), '[]'::jsonb));
    END IF;
  END IF;

  row.content := content;
  RETURN row;
END;
$$;

-- Principal: list teachers
CREATE OR REPLACE FUNCTION public.principal_list_teachers()
RETURNS TABLE(id uuid, full_name text, email text, created_at timestamptz, lesson_count bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT p.id, p.full_name, u.email::text, p.created_at,
    (SELECT count(*) FROM public.lessons l WHERE l.teacher_id = p.id) AS lesson_count
  FROM public.profiles p
  JOIN auth.users u ON u.id = p.id
  WHERE public.has_role(auth.uid(), 'principal'::public.app_role)
    AND public.has_role(p.id, 'teacher'::public.app_role)
  ORDER BY p.created_at DESC;
$$;

-- Principal: delete teacher account (and their lessons cascade via app cleanup)
CREATE OR REPLACE FUNCTION public.principal_delete_teacher(_teacher_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.has_role(auth.uid(), 'principal'::public.app_role) THEN
    RAISE EXCEPTION 'Only principals may delete teacher accounts' USING ERRCODE = '42501';
  END IF;
  IF NOT public.has_role(_teacher_id, 'teacher'::public.app_role) THEN
    RAISE EXCEPTION 'Target user is not a teacher' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.student_notifications
    WHERE notification_id IN (SELECT id FROM public.notifications WHERE teacher_id = _teacher_id);
  DELETE FROM public.notifications WHERE teacher_id = _teacher_id;
  DELETE FROM public.teacher_integrations WHERE teacher_id = _teacher_id;
  DELETE FROM public.homework_submissions
    WHERE lesson_id IN (SELECT id FROM public.lessons WHERE teacher_id = _teacher_id);
  DELETE FROM public.quiz_attempts
    WHERE lesson_id IN (SELECT id FROM public.lessons WHERE teacher_id = _teacher_id);
  DELETE FROM public.lessons WHERE teacher_id = _teacher_id;
  DELETE FROM public.user_roles WHERE user_id = _teacher_id;
  DELETE FROM public.profiles WHERE id = _teacher_id;
  DELETE FROM auth.users WHERE id = _teacher_id;
END;
$$;

-- Principal: aggregate progress across ALL students/lessons
CREATE OR REPLACE FUNCTION public.principal_all_progress()
RETURNS TABLE(student_id uuid, full_name text, assigned_grade text, quizzes bigint, avg_score numeric, homework bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  WITH q AS (
    SELECT qa.student_id,
           COUNT(*) AS quizzes,
           AVG(CASE WHEN qa.total > 0 THEN (qa.score::numeric / qa.total) * 100 ELSE 0 END) AS avg_score
    FROM public.quiz_attempts qa
    GROUP BY qa.student_id
  ),
  h AS (
    SELECT hs.student_id, COUNT(*) AS homework
    FROM public.homework_submissions hs
    GROUP BY hs.student_id
  ),
  ids AS (
    SELECT p.id AS student_id FROM public.profiles p
    WHERE public.has_role(p.id, 'student'::public.app_role)
  )
  SELECT ids.student_id, p.full_name, p.assigned_grade,
         COALESCE(q.quizzes, 0),
         COALESCE(ROUND(q.avg_score), 0),
         COALESCE(h.homework, 0)
  FROM ids
  LEFT JOIN public.profiles p ON p.id = ids.student_id
  LEFT JOIN q ON q.student_id = ids.student_id
  LEFT JOIN h ON h.student_id = ids.student_id
  WHERE public.has_role(auth.uid(), 'principal'::public.app_role);
$$;

GRANT EXECUTE ON FUNCTION public.list_lessons_for_viewer() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_lesson_full(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_lesson_for_viewer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.principal_list_teachers() TO authenticated;
GRANT EXECUTE ON FUNCTION public.principal_delete_teacher(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.principal_all_progress() TO authenticated;
