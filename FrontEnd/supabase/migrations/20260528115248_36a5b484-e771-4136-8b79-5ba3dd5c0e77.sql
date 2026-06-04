
CREATE OR REPLACE FUNCTION public.promote_to_teacher(_code text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
BEGIN
  IF _uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  IF _code IS DISTINCT FROM 'AIPATHSHALA2024' THEN
    RAISE EXCEPTION 'Invalid teacher code' USING ERRCODE = '42501';
  END IF;

  -- Upsert: replace any existing role row(s) for this user with 'teacher'
  DELETE FROM public.user_roles WHERE user_id = _uid;
  INSERT INTO public.user_roles (user_id, role) VALUES (_uid, 'teacher');
END;
$$;

REVOKE ALL ON FUNCTION public.promote_to_teacher(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.promote_to_teacher(text) TO authenticated;
