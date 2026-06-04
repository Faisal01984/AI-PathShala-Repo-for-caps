
-- Promote faisal01984@gmail.com to principal (replace any existing role)
DO $$
DECLARE _uid uuid;
BEGIN
  SELECT id INTO _uid FROM auth.users WHERE lower(email) = lower('faisal01984@gmail.com') LIMIT 1;
  IF _uid IS NOT NULL THEN
    DELETE FROM public.user_roles WHERE user_id = _uid;
    INSERT INTO public.user_roles (user_id, role) VALUES (_uid, 'principal');
  END IF;
END $$;

-- View policies for principal
CREATE POLICY "Principals view all lessons" ON public.lessons
  FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'principal'::public.app_role));

CREATE POLICY "Principals view all profiles" ON public.profiles
  FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'principal'::public.app_role));

CREATE POLICY "Principals view all submissions" ON public.homework_submissions
  FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'principal'::public.app_role));

CREATE POLICY "Principals view all quiz attempts" ON public.quiz_attempts
  FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'principal'::public.app_role));

CREATE POLICY "Principals view all roles" ON public.user_roles
  FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'principal'::public.app_role));

-- Delete policies for principal
CREATE POLICY "Principals delete any lesson" ON public.lessons
  FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'principal'::public.app_role));

CREATE POLICY "Principals delete any submission" ON public.homework_submissions
  FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'principal'::public.app_role));

-- Allow principal delete on quiz_attempts (no delete policy existed)
CREATE POLICY "Principals delete any quiz attempt" ON public.quiz_attempts
  FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'principal'::public.app_role));

-- Admin function: delete a student account fully (auth user + cascades)
CREATE OR REPLACE FUNCTION public.principal_delete_student(_student_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.has_role(auth.uid(), 'principal'::public.app_role) THEN
    RAISE EXCEPTION 'Only principals may delete student accounts' USING ERRCODE = '42501';
  END IF;
  IF NOT public.has_role(_student_id, 'student'::public.app_role) THEN
    RAISE EXCEPTION 'Target user is not a student' USING ERRCODE = '42501';
  END IF;
  -- Remove app data
  DELETE FROM public.homework_submissions WHERE student_id = _student_id;
  DELETE FROM public.quiz_attempts WHERE student_id = _student_id;
  DELETE FROM public.student_notifications WHERE student_id = _student_id;
  DELETE FROM public.user_roles WHERE user_id = _student_id;
  DELETE FROM public.profiles WHERE id = _student_id;
  -- Remove auth user
  DELETE FROM auth.users WHERE id = _student_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.principal_delete_student(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.principal_delete_student(uuid) TO authenticated;

-- Convenience: list everything for principal
CREATE OR REPLACE FUNCTION public.principal_list_students()
RETURNS TABLE(id uuid, full_name text, email text, assigned_grade text, special_class boolean, created_at timestamptz)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id, p.full_name, u.email::text, p.assigned_grade, p.special_class, p.created_at
  FROM public.profiles p
  JOIN auth.users u ON u.id = p.id
  WHERE public.has_role(auth.uid(), 'principal'::public.app_role)
    AND public.has_role(p.id, 'student'::public.app_role)
  ORDER BY p.created_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.principal_list_students() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.principal_list_students() TO authenticated;

CREATE OR REPLACE FUNCTION public.principal_list_lessons()
RETURNS TABLE(id uuid, title text, subject text, grade text, target_grade text, teacher_id uuid, teacher_name text, created_at timestamptz)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT l.id, l.title, l.subject, l.grade, l.target_grade, l.teacher_id,
         COALESCE(p.full_name, u.email::text) AS teacher_name, l.created_at
  FROM public.lessons l
  LEFT JOIN public.profiles p ON p.id = l.teacher_id
  LEFT JOIN auth.users u ON u.id = l.teacher_id
  WHERE public.has_role(auth.uid(), 'principal'::public.app_role)
  ORDER BY l.created_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.principal_list_lessons() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.principal_list_lessons() TO authenticated;

CREATE OR REPLACE FUNCTION public.principal_list_submissions()
RETURNS TABLE(id uuid, file_name text, lesson_id uuid, lesson_title text, student_id uuid, student_name text, created_at timestamptz)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT hs.id, hs.file_name, hs.lesson_id, l.title AS lesson_title,
         hs.student_id, COALESCE(p.full_name, u.email::text) AS student_name, hs.created_at
  FROM public.homework_submissions hs
  LEFT JOIN public.lessons l ON l.id = hs.lesson_id
  LEFT JOIN public.profiles p ON p.id = hs.student_id
  LEFT JOIN auth.users u ON u.id = hs.student_id
  WHERE public.has_role(auth.uid(), 'principal'::public.app_role)
  ORDER BY hs.created_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION public.principal_list_submissions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.principal_list_submissions() TO authenticated;
