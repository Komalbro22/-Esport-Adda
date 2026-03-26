-- Add maintenance and update configuration columns to app_settings
ALTER TABLE public.app_settings 
ADD COLUMN IF NOT EXISTS is_maintenance_mode BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS maintenance_message TEXT DEFAULT 'We are currently under maintenance. Please check back later.',
ADD COLUMN IF NOT EXISTS user_app_version TEXT DEFAULT '1.0.0',
ADD COLUMN IF NOT EXISTS user_app_update_url TEXT DEFAULT 'https://esportadda.in/downloads/esport_adda_user.apk';

-- Update existing row with default values if necessary
UPDATE public.app_settings 
SET 
  is_maintenance_mode = COALESCE(is_maintenance_mode, FALSE),
  maintenance_message = COALESCE(maintenance_message, 'We are currently under maintenance. Please check back later.'),
  user_app_version = COALESCE(user_app_version, '1.0.0'),
  user_app_update_url = COALESCE(user_app_update_url, 'https://esportadda.in/downloads/esport_adda_user.apk')
WHERE id IS NOT NULL;

-- Enable Realtime for app_settings safely
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND schemaname = 'public' 
        AND tablename = 'app_settings'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.app_settings;
    END IF;
END $$;

-- Enable RLS for app_settings
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

-- Policy: Allow admins to manage app_settings
DROP POLICY IF EXISTS "Admins can manage app_settings" ON public.app_settings;
CREATE POLICY "Admins can manage app_settings"
  ON public.app_settings
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
    )
  );

-- Ensure only one row exists in app_settings to prevent state confusion
DELETE FROM public.app_settings WHERE id NOT IN (SELECT id FROM public.app_settings LIMIT 1);
