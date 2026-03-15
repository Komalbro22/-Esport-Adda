-- Comprehensive Bonus & User Verification Logic Fix
-- This script resolves:
-- 1. Users appearing in Admin before OTP verification.
-- 2. Balance discrepancies (Double awarding).
-- 3. Robust bonus tracking.

-- 1. CLEANUP: Remove the trigger that creates users/wallets before verification
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 2. ENSURE: app_settings has correct columns
ALTER TABLE public.app_settings 
ADD COLUMN IF NOT EXISTS signup_bonus NUMERIC DEFAULT 10,
ADD COLUMN IF NOT EXISTS referral_bonus_sender NUMERIC DEFAULT 10,
ADD COLUMN IF NOT EXISTS referral_bonus_receiver NUMERIC DEFAULT 10;

-- 3. ROBUST Wallet Increment Function (Atomic)
-- Handles both deposit (referrals/bonuses) and winning (tournaments) wallets
CREATE OR REPLACE FUNCTION public.increment_wallet_v2(
    p_user_id UUID, 
    p_amount NUMERIC, 
    p_wallet_type TEXT, -- 'deposit' or 'winning'
    p_transaction_type TEXT, 
    p_reference_id TEXT,
    p_message TEXT DEFAULT NULL
)
RETURNS void AS $$
BEGIN
    -- 1. Upsert the wallet (creates if missing, uses COALESCE to handle NULLs gracefully)
    IF p_wallet_type = 'winning' THEN
        INSERT INTO public.user_wallets (user_id, winning_wallet)
        VALUES (p_user_id, p_amount)
        ON CONFLICT (user_id) DO UPDATE
        SET winning_wallet = COALESCE(user_wallets.winning_wallet, 0) + p_amount,
            updated_at = timezone('utc'::text, now());
    ELSE
        INSERT INTO public.user_wallets (user_id, deposit_wallet)
        VALUES (p_user_id, p_amount)
        ON CONFLICT (user_id) DO UPDATE
        SET deposit_wallet = COALESCE(user_wallets.deposit_wallet, 0) + p_amount,
            updated_at = timezone('utc'::text, now());
    END IF;

    -- 2. Log transaction
    INSERT INTO public.wallet_transactions (
        user_id, 
        amount, 
        type, 
        wallet_type, 
        status, 
        reference_id,
        message
    )
    VALUES (
        p_user_id, 
        p_amount, 
        p_transaction_type, 
        p_wallet_type, 
        'completed', 
        p_reference_id,
        p_message
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.increment_wallet_v2(UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT) TO service_role;

-- 4. Signup Bonus Trigger (Strictly once-per-user)
CREATE OR REPLACE FUNCTION public.handle_new_user_signup_bonus()
RETURNS TRIGGER AS $$
DECLARE
    v_bonus NUMERIC;
    v_exists BOOLEAN;
BEGIN
    -- Fetch config
    SELECT signup_bonus INTO v_bonus FROM public.app_settings LIMIT 1;
    v_bonus := COALESCE(v_bonus, 10);

    -- CHECK: Has this user EVER received a 'signup_bonus' transaction?
    -- This is the most reliable way to avoid double rewards.
    SELECT EXISTS (
        SELECT 1 FROM public.wallet_transactions 
        WHERE user_id = NEW.user_id AND type = 'signup_bonus'
    ) INTO v_exists;

    IF NOT v_exists THEN
        -- Add the bonus to the initial balance
        NEW.deposit_wallet := NEW.deposit_wallet + v_bonus;
        
        -- Note: We log the transaction in an AFTER trigger to ensure 
        -- the user_wallets record exists first.
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.log_signup_bonus_after()
RETURNS TRIGGER AS $$
DECLARE
    v_bonus NUMERIC;
    v_already_logged BOOLEAN;
BEGIN
    SELECT signup_bonus INTO v_bonus FROM public.app_settings LIMIT 1;
    v_bonus := COALESCE(v_bonus, 10);

    SELECT EXISTS (
        SELECT 1 FROM public.wallet_transactions 
        WHERE user_id = NEW.user_id AND type = 'signup_bonus'
    ) INTO v_already_logged;

    IF NOT v_already_logged THEN
        INSERT INTO public.wallet_transactions (user_id, amount, type, wallet_type, status, reference_id)
        VALUES (NEW.user_id, v_bonus, 'signup_bonus', 'deposit', 'completed', 'Welcome Signup Bonus');
        
        INSERT INTO public.user_activity_logs (user_id, activity_type, description)
        VALUES (NEW.user_id, 'signup_bonus_received', 'Received ₹' || v_bonus || ' signup bonus');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-setup triggers
DROP TRIGGER IF EXISTS tr_signup_bonus_val ON public.user_wallets;
CREATE TRIGGER tr_signup_bonus_val
BEFORE INSERT ON public.user_wallets
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_signup_bonus();

DROP TRIGGER IF EXISTS tr_signup_bonus_log ON public.user_wallets;
CREATE TRIGGER tr_signup_bonus_log
AFTER INSERT ON public.user_wallets
FOR EACH ROW EXECUTE FUNCTION public.log_signup_bonus_after();

-- 5. Permissions
GRANT EXECUTE ON FUNCTION public.increment_wallet_v2(UUID, NUMERIC, TEXT, TEXT, TEXT, TEXT) TO service_role;
GRANT ALL ON public.app_settings TO service_role;
GRANT ALL ON public.user_wallets TO service_role;
GRANT ALL ON public.wallet_transactions TO service_role;
GRANT ALL ON public.user_activity_logs TO service_role;
