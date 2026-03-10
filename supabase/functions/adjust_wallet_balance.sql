-- Function to adjust wallet balance and log transaction atomically
CREATE OR REPLACE FUNCTION adjust_wallet_balance(
    p_user_id uuid,
    p_amount numeric,
    p_type text,
    p_ref_id text
) RETURNS void AS $$
DECLARE
    v_current_winning numeric;
    v_current_deposit numeric;
BEGIN
    -- Get current balances
    SELECT winning_wallet, deposit_wallet INTO v_current_winning, v_current_deposit
    FROM public.user_wallets
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Wallet not found for user %', p_user_id;
    END IF;

    -- For prizes and refunds, we typically add to winning_wallet or deposit_wallet
    -- Here we default prizes to winning_wallet and refunds to deposit_wallet
    IF p_type = 'challenge_prize' THEN
        UPDATE public.user_wallets
        SET winning_wallet = winning_wallet + p_amount
        WHERE user_id = p_user_id;
        
        INSERT INTO public.wallet_transactions (user_id, amount, type, wallet_type, status, reference_id)
        VALUES (p_user_id, p_amount, p_type, 'winning', 'completed', p_ref_id);
    
    ELSIF p_type = 'challenge_refund' THEN
        UPDATE public.user_wallets
        SET deposit_wallet = deposit_wallet + p_amount
        WHERE user_id = p_user_id;
        
        INSERT INTO public.wallet_transactions (user_id, amount, type, wallet_type, status, reference_id)
        VALUES (p_user_id, p_amount, p_type, 'deposit', 'completed', p_ref_id);
    
    ELSE
        -- Default behavior for other types (if any)
        UPDATE public.user_wallets
        SET deposit_wallet = deposit_wallet + p_amount
        WHERE user_id = p_user_id;
        
        INSERT INTO public.wallet_transactions (user_id, amount, type, wallet_type, status, reference_id)
        VALUES (p_user_id, p_amount, 'other', 'deposit', 'completed', p_ref_id);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
