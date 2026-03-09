-- ============================================================
-- Esport Adda — User Activity Logs & Legal Documents Migration
-- ============================================================

-- 1. user_activity_logs table
CREATE TABLE IF NOT EXISTS public.user_activity_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  activity_type text NOT NULL,
  description text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. legal_documents table
CREATE TABLE IF NOT EXISTS public.legal_documents (
  id text PRIMARY KEY, -- 'privacy_policy', 'terms_and_conditions', 'refund_policy'
  title text NOT NULL,
  content text NOT NULL, -- Markdown content
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. RLS for user_activity_logs
ALTER TABLE public.user_activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own logs" ON public.user_activity_logs;
CREATE POLICY "Users can view their own logs"
  ON public.user_activity_logs FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can view all logs" ON public.user_activity_logs;
CREATE POLICY "Admins can view all logs"
  ON public.user_activity_logs FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
  );

-- 4. RLS for legal_documents
ALTER TABLE public.legal_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Legal documents are viewable by everyone" ON public.legal_documents;
CREATE POLICY "Legal documents are viewable by everyone"
  ON public.legal_documents FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Admins can manage legal documents" ON public.legal_documents;
CREATE POLICY "Admins can manage legal documents"
  ON public.legal_documents FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
  );

-- 5. Seed legal documents
INSERT INTO public.legal_documents (id, title, content)
VALUES 
  ('privacy_policy', 'Privacy Policy', '# Privacy Policy\n\nYour privacy is important to us...'),
  ('terms_and_conditions', 'Terms and Conditions', '# Terms and Conditions\n\nBy using this app, you agree to...'),
  ('refund_policy', 'Refund Policy', '# Refund Policy\n\nRefunds are processed according to...')
ON CONFLICT (id) DO NOTHING;
