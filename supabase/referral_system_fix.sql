-- 1. Create app_settings table (required by Edge Function)
CREATE TABLE IF NOT EXISTS public.app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referral_bonus_sender NUMERIC DEFAULT 10,
    referral_bonus_receiver NUMERIC DEFAULT 10,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Insert default values if not exists
INSERT INTO public.app_settings (referral_bonus_sender, referral_bonus_receiver)
SELECT 10, 10
WHERE NOT EXISTS (SELECT 1 FROM public.app_settings);

-- 2. Create the missing RPC function for wallets
CREATE OR REPLACE FUNCTION public.increment_deposit_wallet(u_id UUID, amt NUMERIC)
RETURNS void AS $$
BEGIN
    -- Ensure wallet exists, then increment
    INSERT INTO public.user_wallets (user_id, deposit_wallet, winning_wallet, total_kills, total_wins, matches_played)
    VALUES (u_id, amt, 0, 0, 0, 0)
    ON CONFLICT (user_id) DO UPDATE
    SET deposit_wallet = user_wallets.deposit_wallet + amt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Grant permissions to execute functions
GRANT EXECUTE ON FUNCTION public.increment_deposit_wallet(UUID, NUMERIC) TO service_role;
GRANT ALL ON public.app_settings TO service_role;
GRANT SELECT ON public.app_settings TO authenticated;
