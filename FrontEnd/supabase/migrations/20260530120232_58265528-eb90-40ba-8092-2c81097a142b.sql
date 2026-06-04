-- Add teacher linking to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS teacher_id UUID;

-- Add flag to quiz_attempts for "Extra Activities" (target_grade='All' lessons)
ALTER TABLE public.quiz_attempts ADD COLUMN IF NOT EXISTS is_extra_activity BOOLEAN NOT NULL DEFAULT false;

-- Helper RPC: a student calls this after signup with their teacher's code.
-- Code format: "TEACHER_" + first 6 hex chars of teacher user_id.
CREATE OR REPLACE FUNCTION public.link_student_to_teacher(_code text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
  _prefix text;
  _teacher uuid;
BEGIN
  IF _uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF _code IS NULL OR length(trim(_code)) = 0 THEN
    RETURN NULL;
  END IF;
  IF upper(left(_code, 8)) <> 'TEACHER_' OR length(_code) < 14 THEN
    RAISE EXCEPTION 'Invalid teacher code format' USING ERRCODE = '22023';
  END IF;
  _prefix := lower(substring(_code from 9 for 6));
  SELECT ur.user_id INTO _teacher
  FROM public.user_roles ur
  WHERE ur.role = 'teacher'::public.app_role
    AND lower(substring(ur.user_id::text, 1, 6)) = _prefix
  LIMIT 1;
  IF _teacher IS NULL THEN
    RAISE EXCEPTION 'No teacher found for that code' USING ERRCODE = '42704';
  END IF;
  UPDATE public.profiles SET teacher_id = _teacher, updated_at = now() WHERE id = _uid;
  RETURN _teacher;
END;
$$;
GRANT EXECUTE ON FUNCTION public.link_student_to_teacher(text) TO authenticated;

-- Update progress RPCs to ignore Extra Activity attempts in the main average
CREATE OR REPLACE FUNCTION public.get_teacher_progress()
 RETURNS TABLE(student_id uuid, full_name text, assigned_grade text, quizzes bigint, avg_score numeric, homework bigint)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  WITH my_lessons AS (
    SELECT id FROM public.lessons WHERE teacher_id = auth.uid()
  ),
  q AS (
    SELECT qa.student_id,
           COUNT(*) AS quizzes,
           AVG(CASE WHEN qa.total > 0 THEN (qa.score::numeric / qa.total) * 100 ELSE 0 END) AS avg_score
    FROM public.quiz_attempts qa
    WHERE qa.lesson_id IN (SELECT id FROM my_lessons)
      AND COALESCE(qa.is_extra_activity, false) = false
    GROUP BY qa.student_id
  ),
  h AS (
    SELECT hs.student_id, COUNT(*) AS homework
    FROM public.homework_submissions hs
    WHERE hs.lesson_id IN (SELECT id FROM my_lessons)
    GROUP BY hs.student_id
  ),
  ids AS (
    SELECT student_id FROM q UNION SELECT student_id FROM h
  )
  SELECT ids.student_id, p.full_name, p.assigned_grade,
         COALESCE(q.quizzes, 0), COALESCE(ROUND(q.avg_score), 0), COALESCE(h.homework, 0)
  FROM ids
  LEFT JOIN public.profiles p ON p.id = ids.student_id
  LEFT JOIN q ON q.student_id = ids.student_id
  LEFT JOIN h ON h.student_id = ids.student_id
  WHERE public.has_role(auth.uid(), 'teacher');
$function$;

CREATE OR REPLACE FUNCTION public.principal_all_progress()
 RETURNS TABLE(student_id uuid, full_name text, assigned_grade text, quizzes bigint, avg_score numeric, homework bigint)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
  WITH q AS (
    SELECT qa.student_id,
           COUNT(*) AS quizzes,
           AVG(CASE WHEN qa.total > 0 THEN (qa.score::numeric / qa.total) * 100 ELSE 0 END) AS avg_score
    FROM public.quiz_attempts qa
    WHERE COALESCE(qa.is_extra_activity, false) = false
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
         COALESCE(q.quizzes, 0), COALESCE(ROUND(q.avg_score), 0), COALESCE(h.homework, 0)
  FROM ids
  LEFT JOIN public.profiles p ON p.id = ids.student_id
  LEFT JOIN q ON q.student_id = ids.student_id
  LEFT JOIN h ON h.student_id = ids.student_id
  WHERE public.has_role(auth.uid(), 'principal'::public.app_role);
$function$;