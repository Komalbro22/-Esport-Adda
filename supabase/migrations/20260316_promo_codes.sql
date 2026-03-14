-- Migration to support Promo Codes

-- 1. Create promo_codes table
CREATE TABLE IF NOT EXISTS public.promo_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    reward_amount NUMERIC NOT NULL,
    reward_type TEXT NOT NULL CHECK (reward_type IN ('deposit', 'winning')),
    usage_type TEXT NOT NULL CHECK (usage_type IN ('unlimited', 'limited')),
    usage_limit INTEGER, -- NULL if unlimited
    times_used INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Create promo_code_redemptions table
CREATE TABLE IF NOT EXISTS public.promo_code_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promo_code_id UUID REFERENCES public.promo_codes(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    redeemed_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(promo_code_id, user_id) -- One user can redeem a code only once
);

-- 3. Enable RLS
ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promo_code_redemptions ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for promo_codes
-- Everyone can select (to check if code exists, but best behind edge function)
-- Actually, let's restrict select to admins for privacy of all codes, or let edge function handle it.
-- We'll allow authenticated users to select to facilitate simple client-side checks if needed.
CREATE POLICY "Promo codes are viewable by everyone" ON public.promo_codes
    FOR SELECT USING (true);

CREATE POLICY "Admins can manage promo codes" ON public.promo_codes
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- 5. RLS Policies for promo_code_redemptions
CREATE POLICY "Users can view their own redemptions" ON public.promo_code_redemptions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all redemptions" ON public.promo_code_redemptions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
        )
    );

-- 6. Trigger to update updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_promo_codes_updated_at
    BEFORE UPDATE ON public.promo_codes
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();
