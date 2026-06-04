GRANT EXECUTE ON FUNCTION public.has_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_role(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_assigned_grade(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_special_class(uuid) TO authenticated;