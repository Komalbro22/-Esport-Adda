-- RPC Function to safely process a voucher withdrawal atomically
CREATE OR REPLACE FUNCTION public.process_voucher_withdrawal(
  p_user_id UUID,
  p_category_id UUID,
  p_amount NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_winning_wallet NUMERIC;
  v_voucher_id UUID;
  v_voucher_code TEXT;
  v_request_id UUID;
  v_result JSONB;
BEGIN
  -- 1. Check user winning wallet balance
  -- Use FOR UPDATE to lock the balance during the transaction
  SELECT winning_wallet INTO v_winning_wallet 
  FROM public.user_wallets 
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_winning_wallet IS NULL OR v_winning_wallet < p_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'Insufficient winning balance.');
  END IF;

  -- 2. Try to lock and acquire an available voucher
  -- Cast p_amount to numeric(20,2) or similar if needed, but since it's numeric already,
  -- we just ensure the comparison is clean.
  SELECT id, voucher_code 
  INTO v_voucher_id, v_voucher_code
  FROM public.voucher_codes
  WHERE category_id = p_category_id 
    AND amount = p_amount 
    AND status = 'available'
  FOR UPDATE SKIP LOCKED
  LIMIT 1;

  IF v_voucher_id IS NOT NULL THEN
    -- Voucher found! Deliver it instantly.
    
    -- Update voucher status
    UPDATE public.voucher_codes
    SET status = 'used',
        used_by = p_user_id,
        used_at = now()
    WHERE id = v_voucher_id;

    -- Deduct from wallet
    UPDATE public.user_wallets
    SET winning_wallet = winning_wallet - p_amount
    WHERE user_id = p_user_id;

    -- Create wallet transaction
    INSERT INTO public.wallet_transactions (
      user_id, amount, type, status, description, wallet_type
    ) VALUES (
      p_user_id, -p_amount, 'withdraw', 'completed', 'Voucher Withdrawal (Instant)', 'winning'
    );

    v_result := jsonb_build_object(
      'success', true, 
      'status', 'completed', 
      'voucher_code', v_voucher_code,
      'message', 'Voucher redeemed successfully.'
    );
  ELSE
    -- No voucher available, create a pending request
    
    INSERT INTO public.voucher_withdraw_requests (
      user_id, category_id, amount, status
    ) VALUES (
      p_user_id, p_category_id, p_amount, 'pending'
    ) RETURNING id INTO v_request_id;

    -- Deduct from wallet instantly (funds are held)
    UPDATE public.user_wallets
    SET winning_wallet = winning_wallet - p_amount
    WHERE user_id = p_user_id;

    -- Create pending wallet transaction
    INSERT INTO public.wallet_transactions (
      user_id, amount, type, status, description, wallet_type, reference_id
    ) VALUES (
      p_user_id, -p_amount, 'withdraw', 'pending', 'Voucher Withdrawal (Pending)', 'winning', v_request_id::TEXT
    );

    v_result := jsonb_build_object(
      'success', true, 
      'status', 'pending', 
      'message', 'No voucher code currently available. A manual request has been submitted.'
    );
  END IF;

  RETURN v_result;
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- RPC to safely deduct balance from any wallet type
CREATE OR REPLACE FUNCTION public.deduct_wallet_balance(
  p_user_id UUID,
  p_amount NUMERIC,
  p_wallet_type TEXT -- 'deposit' or 'winning'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_wallet_type = 'winning' THEN
    UPDATE public.user_wallets
    SET winning_wallet = winning_wallet - p_amount
    WHERE user_id = p_user_id AND winning_wallet >= p_amount;
  ELSIF p_wallet_type = 'deposit' THEN
    UPDATE public.user_wallets
    SET deposit_wallet = deposit_wallet - p_amount
    WHERE user_id = p_user_id AND deposit_wallet >= p_amount;
  ELSE
    RETURN FALSE;
  END IF;

  RETURN FOUND;
END;
$$;

