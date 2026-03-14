-- ============================================================
-- Esport Adda — Storage Bucket for APKs
-- ============================================================

-- 1. Create a public bucket for APKs if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('apks', 'apks', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Allow public access to read APKs
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id = 'apks');

-- 3. Allow authenticated admins to upload/update APKs
DROP POLICY IF EXISTS "Admins can upload APKs" ON storage.objects;
CREATE POLICY "Admins can upload APKs"
ON storage.objects FOR ALL
TO authenticated
USING (
  bucket_id = 'apks' AND 
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
)
WITH CHECK (
  bucket_id = 'apks' AND 
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
);
