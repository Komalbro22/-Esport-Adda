-- Support functions for Promo Codes and Wallets

-- 1. Function to increment promo code usage
CREATE OR REPLACE FUNCTION public.increment_promo_usage(p_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE public.promo_codes
    SET times_used = times_used + 1
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Function to increment winning wallet
CREATE OR REPLACE FUNCTION public.increment_winning_wallet(u_id UUID, amt NUMERIC)
RETURNS void AS $$
BEGIN
    INSERT INTO public.user_wallets (user_id, deposit_wallet, winning_wallet, total_kills, total_wins, matches_played)
    VALUES (u_id, 0, amt, 0, 0, 0)
    ON CONFLICT (user_id) DO UPDATE
    SET winning_wallet = user_wallets.winning_wallet + amt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Grant execution permissions
GRANT EXECUTE ON FUNCTION public.increment_promo_usage(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.increment_winning_wallet(UUID, NUMERIC) TO service_role;
