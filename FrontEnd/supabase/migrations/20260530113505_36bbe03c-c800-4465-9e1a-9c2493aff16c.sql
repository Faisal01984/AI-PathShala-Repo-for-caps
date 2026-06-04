CREATE OR REPLACE FUNCTION public.get_lesson_students_full(_lesson_id uuid)
RETURNS TABLE(id uuid, full_name text, roll_number text, email text)
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
  SELECT p.id, p.full_name, p.roll_number, u.email::text
  FROM public.profiles p
  LEFT JOIN auth.users u ON u.id = p.id
  WHERE (
    EXISTS (SELECT 1 FROM public.lessons l WHERE l.id = _lesson_id
      AND (l.teacher_id = auth.uid() OR public.has_role(auth.uid(), 'principal'::public.app_role)))
  ) AND (
    EXISTS (SELECT 1 FROM public.homework_submissions hs WHERE hs.lesson_id = _lesson_id AND hs.student_id = p.id)
    OR EXISTS (SELECT 1 FROM public.quiz_attempts qa WHERE qa.lesson_id = _lesson_id AND qa.student_id = p.id)
  );
$function$;

GRANT EXECUTE ON FUNCTION public.get_lesson_students_full(uuid) TO authenticated;