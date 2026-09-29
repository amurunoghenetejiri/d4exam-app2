ALTER TABLE public.examinations ADD COLUMN IF NOT EXISTS questions_to_answer integer, ADD COLUMN IF NOT EXISTS total_marks numeric;
ALTER TABLE public.questions ADD COLUMN IF NOT EXISTS options jsonb NOT NULL DEFAULT '[]'::jsonb, ADD COLUMN IF NOT EXISTS correct_answer text;
ALTER TABLE public.course_materials ADD COLUMN IF NOT EXISTS ocr_text text, ADD COLUMN IF NOT EXISTS ocr_status text, ADD COLUMN IF NOT EXISTS converted_pdf_url text;
ALTER TABLE public.exam_settings ADD COLUMN IF NOT EXISTS allow_calculator boolean NOT NULL DEFAULT false, ADD COLUMN IF NOT EXISTS calculator_type text NOT NULL DEFAULT 'basic', ADD COLUMN IF NOT EXISTS questions_to_answer integer;
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS code text GENERATED ALWAYS AS (school_code) STORED;
ALTER TABLE public.teachers ADD COLUMN IF NOT EXISTS full_name text;

CREATE TABLE IF NOT EXISTS public.question_options (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  question_id uuid NOT NULL REFERENCES public.questions(id) ON DELETE CASCADE,
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  option_key text NOT NULL, option_text text NOT NULL,
  is_correct boolean NOT NULL DEFAULT false, sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (question_id, option_key));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.question_options TO authenticated;
GRANT ALL ON public.question_options TO service_role;
ALTER TABLE public.question_options ENABLE ROW LEVEL SECURITY;
CREATE POLICY "question_options_select" ON public.question_options FOR SELECT TO authenticated USING (public.in_school(school_id));
CREATE POLICY "question_options_write" ON public.question_options FOR ALL TO authenticated USING (public.in_school(school_id)) WITH CHECK (public.in_school(school_id));

CREATE TABLE IF NOT EXISTS public.course_enrollments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (student_id, course_id));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.course_enrollments TO authenticated;
GRANT ALL ON public.course_enrollments TO service_role;
ALTER TABLE public.course_enrollments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "course_enrollments_select" ON public.course_enrollments FOR SELECT TO authenticated USING (public.in_school(school_id));
CREATE POLICY "course_enrollments_write" ON public.course_enrollments FOR ALL TO authenticated USING (public.can_manage_school(school_id)) WITH CHECK (public.can_manage_school(school_id));

CREATE TABLE IF NOT EXISTS public.course_carryovers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  original_level_id uuid REFERENCES public.levels(id) ON DELETE SET NULL,
  reason text, status text NOT NULL DEFAULT 'active', created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (school_id, student_id, course_id));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.course_carryovers TO authenticated;
GRANT ALL ON public.course_carryovers TO service_role;
ALTER TABLE public.course_carryovers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "course_carryovers_select_school" ON public.course_carryovers FOR SELECT TO authenticated USING (public.in_school(school_id));
CREATE POLICY "course_carryovers_write_staff" ON public.course_carryovers FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.school_id = course_carryovers.school_id AND ur.role::text IN ('school_admin','examination_officer','super_admin')))
  WITH CHECK (EXISTS (SELECT 1 FROM public.user_roles ur WHERE ur.user_id = auth.uid() AND ur.school_id = course_carryovers.school_id AND ur.role::text IN ('school_admin','examination_officer','super_admin')));

CREATE TABLE IF NOT EXISTS public.student_officer_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  student_id uuid, student_user_id uuid, student_name text, student_matric text,
  exam_id uuid, exam_title text, exam_ids uuid[] DEFAULT '{}', exam_titles text[] DEFAULT '{}',
  subject text, body text NOT NULL, status text NOT NULL DEFAULT 'open',
  officer_user_id uuid, officer_reply text, replied_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now());
GRANT SELECT, INSERT, UPDATE ON public.student_officer_reports TO authenticated;
GRANT ALL ON public.student_officer_reports TO service_role;
ALTER TABLE public.student_officer_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sor_student_select" ON public.student_officer_reports FOR SELECT TO authenticated
  USING (student_user_id = auth.uid() OR student_id IN (SELECT s.id FROM public.students s JOIN public.profiles p ON p.id = s.profile_id WHERE p.auth_user_id = auth.uid()));
CREATE POLICY "sor_student_insert" ON public.student_officer_reports FOR INSERT TO authenticated
  WITH CHECK (student_user_id = auth.uid() OR student_id IN (SELECT s.id FROM public.students s JOIN public.profiles p ON p.id = s.profile_id WHERE p.auth_user_id = auth.uid()));
CREATE POLICY "sor_officer_select" ON public.student_officer_reports FOR SELECT TO authenticated
  USING (school_id IN (SELECT p.school_id FROM public.profiles p WHERE p.auth_user_id = auth.uid() AND p.school_id IS NOT NULL));
CREATE POLICY "sor_officer_update" ON public.student_officer_reports FOR UPDATE TO authenticated
  USING (school_id IN (SELECT p.school_id FROM public.profiles p WHERE p.auth_user_id = auth.uid() AND p.school_id IS NOT NULL));

CREATE TABLE IF NOT EXISTS public.school_admins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (school_id, profile_id));
GRANT SELECT ON public.school_admins TO authenticated;
GRANT ALL ON public.school_admins TO service_role;
ALTER TABLE public.school_admins ENABLE ROW LEVEL SECURITY;
CREATE POLICY "school_admins_select" ON public.school_admins FOR SELECT TO authenticated USING (public.in_school(school_id));

CREATE OR REPLACE FUNCTION public.resolve_login_email(_school_id uuid, _identifier text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.email FROM public.profiles p
  LEFT JOIN public.students s ON s.profile_id = p.id
  LEFT JOIN public.teachers t ON t.profile_id = p.id
  WHERE p.school_id = _school_id AND p.email IS NOT NULL
    AND (lower(s.matric_number) = lower(_identifier) OR lower(s.student_id) = lower(_identifier) OR lower(t.staff_id) = lower(_identifier))
  LIMIT 1
$$;
GRANT EXECUTE ON FUNCTION public.resolve_login_email(uuid, text) TO anon, authenticated;