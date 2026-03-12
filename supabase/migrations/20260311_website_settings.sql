-- Create website_settings table
CREATE TABLE IF NOT EXISTS public.website_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_by UUID REFERENCES auth.users(id)
);

-- Enable RLS
ALTER TABLE public.website_settings ENABLE ROW LEVEL SECURITY;

-- Policy: Public read access
CREATE POLICY "Allow public read access to website_settings"
    ON public.website_settings
    FOR SELECT
    USING (true);

-- Policy: Admin-only write access
CREATE POLICY "Allow admin write access to website_settings"
    ON public.website_settings
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

-- Insert initial settings
INSERT INTO public.website_settings (key, value)
VALUES 
    ('apk_links', '{
        "user_app": "https://esportadda.in/downloads/esport_adda_user.apk",
        "admin_app": "https://esportadda.in/downloads/esport_adda_admin.apk",
        "user_version": "1.0.0",
        "admin_version": "1.0.0"
    }'),
    ('contact_info', '{
        "email": "support@esportadda.in",
        "whatsapp": "+910000000000",
        "instagram": "https://instagram.com/esportadda"
    }'),
    ('app_stats', '{
        "active_players": "50K+",
        "live_matches": "100+",
        "total_tournaments": "500+",
        "prize_distributed": "₹10L+"
    }')
ON CONFLICT (key) DO NOTHING;
