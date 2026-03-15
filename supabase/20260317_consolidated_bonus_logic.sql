-- Consolidated Bonus & Wallet Logic
-- This script sets up the infrastructure for Signup Bonuses, Referral Bonuses, and Promo Code redemptions.

-- 1. Ensure columns exist in app_settings
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='app_settings' AND column_name='signup_bonus') THEN
        ALTER TABLE public.app_settings ADD COLUMN signup_bonus NUMERIC DEFAULT 10;
    END IF;
END $$;

-- 2. Update wallet_transactions type check constraint
-- This allows 'promo_code' and 'signup_bonus' as valid transaction types.
DO $$ 
BEGIN
    ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;
    ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_type_check 
    CHECK (type IN ('deposit', 'withdraw', 'tournament_entry', 'tournament_win', 'referral_bonus', 'challenge_entry', 'challenge_prize', 'challenge_refund', 'challenge_commission', 'promo_code', 'signup_bonus', 'other'));
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Could not update wallet_transactions_type_check: %', SQLERRM;
END $$;

-- 3. Create/Update Atomic Wallet Increment Functions
CREATE OR REPLACE FUNCTION public.increment_deposit_wallet(u_id UUID, amt NUMERIC)
RETURNS void AS $$
BEGIN
    INSERT INTO public.user_wallets (user_id, deposit_wallet, winning_wallet, total_kills, total_wins, matches_played)
    VALUES (u_id, amt, 0, 0, 0, 0)
    ON CONFLICT (user_id) DO UPDATE
    SET deposit_wallet = user_wallets.deposit_wallet + amt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.increment_winning_wallet(u_id UUID, amt NUMERIC)
RETURNS void AS $$
BEGIN
    INSERT INTO public.user_wallets (user_id, deposit_wallet, winning_wallet, total_kills, total_wins, matches_played)
    VALUES (u_id, 0, amt, 0, 0, 0)
    ON CONFLICT (user_id) DO UPDATE
    SET winning_wallet = user_wallets.winning_wallet + amt;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.increment_promo_usage(p_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE public.promo_codes
    SET times_used = times_used + 1
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Automatic Signup Bonus Trigger
-- This trigger gives the signup bonus as soon as a wallet is created for a new user.
CREATE OR REPLACE FUNCTION public.handle_new_user_signup_bonus()
RETURNS TRIGGER AS $$
DECLARE
    v_signup_bonus NUMERIC;
BEGIN
    -- Fetch current signup bonus from settings
    SELECT signup_bonus INTO v_signup_bonus FROM public.app_settings LIMIT 1;
    v_signup_bonus := COALESCE(v_signup_bonus, 10); -- Default to 10 if not set

    -- Award if it's a fresh wallet creation with 0 balance
    IF (NEW.deposit_wallet = 0 AND NEW.winning_wallet = 0) THEN
        NEW.deposit_wallet := v_signup_bonus;
        
        -- Log the transaction
        INSERT INTO public.wallet_transactions (user_id, amount, type, wallet_type, status, reference_id)
        VALUES (NEW.user_id, v_signup_bonus, 'signup_bonus', 'deposit', 'completed', 'Welcome Bonus');
        
        -- Log activity
        INSERT INTO public.user_activity_logs (user_id, activity_type, description)
        VALUES (NEW.user_id, 'signup_bonus_received', 'Received signup bonus of ₹' || v_signup_bonus);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-create trigger
DROP TRIGGER IF EXISTS on_wallet_created_bonus ON public.user_wallets;
CREATE TRIGGER on_wallet_created_bonus
BEFORE INSERT ON public.user_wallets
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user_signup_bonus();

-- 5. Permissions
GRANT EXECUTE ON FUNCTION public.increment_deposit_wallet(UUID, NUMERIC) TO service_role;
GRANT EXECUTE ON FUNCTION public.increment_winning_wallet(UUID, NUMERIC) TO service_role;
GRANT EXECUTE ON FUNCTION public.increment_promo_usage(UUID) TO service_role;
GRANT ALL ON public.app_settings TO service_role;
GRANT ALL ON public.user_wallets TO service_role;
GRANT ALL ON public.wallet_transactions TO service_role;
GRANT ALL ON public.user_activity_logs TO service_role;
