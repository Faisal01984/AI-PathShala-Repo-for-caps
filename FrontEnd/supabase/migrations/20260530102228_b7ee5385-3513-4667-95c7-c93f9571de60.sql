-- Make teacher role assignment work at signup time by reading the role + teacher code
-- from auth metadata inside the SECURITY DEFINER handle_new_user() trigger.
-- This avoids the previous race where promote_to_teacher() couldn't run because
-- the user had no session yet (email confirmation pending).

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  _level text;
  _ai_class boolean;
  _requested_role text;
  _teacher_code text;
  _final_role public.app_role := 'student';
BEGIN
  _level := NULLIF(NEW.raw_user_meta_data->>'assigned_grade', '');
  IF _level IS NOT NULL AND _level NOT IN ('Beginner','Intermediate','Advanced') THEN
    _level := NULL;
  END IF;
  _ai_class := COALESCE((NEW.raw_user_meta_data->>'special_class')::boolean, false);

  _requested_role := NULLIF(NEW.raw_user_meta_data->>'role', '');
  _teacher_code := NULLIF(NEW.raw_user_meta_data->>'teacher_code', '');

  IF _requested_role = 'teacher' AND _teacher_code = 'AIPATHSHALA2024' THEN
    _final_role := 'teacher';
  END IF;

  INSERT INTO public.profiles (id, full_name, assigned_grade, special_class)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email), _level, _ai_class)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, _final_role)
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$function$;

-- Keep promote_to_teacher available as a backup path for already-existing accounts.
CREATE OR REPLACE FUNCTION public.promote_to_teacher(_code text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  _uid uuid := auth.uid();
BEGIN
  IF _uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF _code IS DISTINCT FROM 'AIPATHSHALA2024' THEN
    RAISE EXCEPTION 'Invalid teacher code' USING ERRCODE = '42501';
  END IF;

  DELETE FROM public.user_roles WHERE user_id = _uid;
  INSERT INTO public.user_roles (user_id, role) VALUES (_uid, 'teacher');
END;
$function$;

GRANT EXECUTE ON FUNCTION public.promote_to_teacher(text) TO authenticated;