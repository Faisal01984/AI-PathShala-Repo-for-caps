
CREATE TABLE public.worksheet_submissions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id UUID NOT NULL,
  lesson_id UUID NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  answers JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.worksheet_submissions TO authenticated;
GRANT ALL ON public.worksheet_submissions TO service_role;

ALTER TABLE public.worksheet_submissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Students manage their own worksheet submissions"
  ON public.worksheet_submissions
  FOR ALL TO authenticated
  USING (student_id = auth.uid())
  WITH CHECK (student_id = auth.uid());

CREATE POLICY "Teachers can view submissions for their lessons"
  ON public.worksheet_submissions
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.lessons l
    WHERE l.id = worksheet_submissions.lesson_id
      AND l.teacher_id = auth.uid()
  ));

CREATE POLICY "Principals can view all worksheet submissions"
  ON public.worksheet_submissions
  FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'principal'::public.app_role));

CREATE POLICY "Principals can delete worksheet submissions"
  ON public.worksheet_submissions
  FOR DELETE TO authenticated
  USING (public.has_role(auth.uid(), 'principal'::public.app_role));

CREATE TRIGGER worksheet_submissions_touch_updated_at
  BEFORE UPDATE ON public.worksheet_submissions
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
