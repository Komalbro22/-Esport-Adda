-- Full shop system enhancements:
-- 1) Store wallet split amounts per order (deposit_amount, winning_amount)
-- 2) Add cancel_shop_order RPC that refunds wallet correctly
-- 3) Update purchase_shop_product to populate the split amounts

-- 1) Add split columns to shop_orders
ALTER TABLE public.shop_orders
  ADD COLUMN IF NOT EXISTS deposit_amount numeric,
  ADD COLUMN IF NOT EXISTS winning_amount numeric;

-- Backfill wallet split for older orders
UPDATE public.shop_orders
SET deposit_amount = amount,
    winning_amount = 0
WHERE paid_from = 'deposit'
  AND (deposit_amount IS NULL OR winning_amount IS NULL);

UPDATE public.shop_orders
SET deposit_amount = 0,
    winning_amount = amount
WHERE paid_from = 'winning'
  AND (deposit_amount IS NULL OR winning_amount IS NULL);

-- For orders paid_from='both' we cannot reconstruct split reliably from the old schema,
-- so we keep split values NULL to prevent incorrect refunds.
UPDATE public.shop_orders
SET deposit_amount = NULL,
    winning_amount = NULL
WHERE paid_from = 'both'
  AND (deposit_amount IS NULL OR winning_amount IS NULL);

-- 2) Update purchase_shop_product to store split amounts
CREATE OR REPLACE FUNCTION public.purchase_shop_product(p_user_id UUID, p_product_id UUID)
RETURNS jsonb AS $$
DECLARE
  v_product RECORD;
  v_wallet RECORD;
  v_global_wallet_type text;
  v_effective_wallet_type text;
  v_to_deduct numeric;
  v_deposit_deducted numeric := 0;
  v_winning_deducted numeric := 0;
  v_paid_from text;
  v_order_id uuid;
BEGIN
  -- Get the product
  SELECT * INTO v_product FROM public.shop_products WHERE id = p_product_id AND is_active = true FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Product not found or inactive');
  END IF;

  -- Get global setting
  SELECT default_shop_wallet_type INTO v_global_wallet_type FROM public.app_settings LIMIT 1;
  IF v_global_wallet_type IS NULL THEN
    v_global_wallet_type := 'both';
  END IF;

  -- Determine effective wallet type
  IF v_product.allowed_wallet_type IS NULL OR v_product.allowed_wallet_type = 'global' THEN
    v_effective_wallet_type := v_global_wallet_type;
  ELSE
    v_effective_wallet_type := v_product.allowed_wallet_type;
  END IF;

  -- Lock and get wallet
  SELECT * INTO v_wallet FROM public.user_wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'User wallet not found');
  END IF;

  v_to_deduct := v_product.price;

  -- Check and deduct balances based on wallet type
  IF v_effective_wallet_type = 'deposit' THEN
    IF v_wallet.deposit_wallet < v_to_deduct THEN
      RETURN jsonb_build_object('success', false, 'message', 'Insufficient deposit balance');
    END IF;
    v_deposit_deducted := v_to_deduct;
    v_paid_from := 'deposit';
  ELSIF v_effective_wallet_type = 'winning' THEN
    IF v_wallet.winning_wallet < v_to_deduct THEN
      RETURN jsonb_build_object('success', false, 'message', 'Insufficient winning balance');
    END IF;
    v_winning_deducted := v_to_deduct;
    v_paid_from := 'winning';
  ELSE -- 'both' (deposit first, then winning)
    IF v_wallet.deposit_wallet + v_wallet.winning_wallet < v_to_deduct THEN
      RETURN jsonb_build_object('success', false, 'message', 'Insufficient balance across both wallets');
    END IF;

    IF v_wallet.deposit_wallet >= v_to_deduct THEN
      v_deposit_deducted := v_to_deduct;
      v_winning_deducted := 0;
    ELSE
      v_deposit_deducted := v_wallet.deposit_wallet;
      v_winning_deducted := v_to_deduct - v_deposit_deducted;
    END IF;
    v_paid_from := 'both';
  END IF;

  -- Update wallet
  UPDATE public.user_wallets
  SET deposit_wallet = deposit_wallet - v_deposit_deducted,
      winning_wallet = winning_wallet - v_winning_deducted
  WHERE user_id = p_user_id;

  -- Record wallet transactions (refund/cancellation will insert opposite transactions)
  IF v_deposit_deducted > 0 THEN
    INSERT INTO public.wallet_transactions (user_id, amount, type, wallet_type, status, reference_id)
    VALUES (p_user_id, v_deposit_deducted, 'withdraw', 'deposit', 'completed', 'shop_purchase_' || p_product_id);
  END IF;

  IF v_winning_deducted > 0 THEN
    INSERT INTO public.wallet_transactions (user_id, amount, type, wallet_type, status, reference_id)
    VALUES (p_user_id, v_winning_deducted, 'withdraw', 'winning', 'completed', 'shop_purchase_' || p_product_id);
  END IF;

  -- Create Order (store split amounts)
  v_order_id := NULL;
  INSERT INTO public.shop_orders (user_id, product_id, amount, paid_from, deposit_amount, winning_amount, status)
  VALUES (p_user_id, p_product_id, v_to_deduct, v_paid_from, v_deposit_deducted, v_winning_deducted, 'pending')
  RETURNING id INTO v_order_id;

  RETURN jsonb_build_object('success', true, 'message', 'Purchase successful', 'order_id', v_order_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3) Cancellation RPC with refund
CREATE OR REPLACE FUNCTION public.cancel_shop_order(p_order_id UUID)
RETURNS jsonb AS $$
DECLARE
  v_order RECORD;
  v_is_admin boolean;
  v_ref text;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Order not found');
  END IF;

  IF v_order.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Only pending orders can be cancelled');
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
  ) INTO v_is_admin;

  IF auth.uid() IS NULL OR (auth.uid() <> v_order.user_id AND COALESCE(v_is_admin, false) = false) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  -- Ensure split values exist (older orders might not)
  IF v_order.deposit_amount IS NULL OR v_order.winning_amount IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Cancellation unavailable for this order (missing wallet split)');
  END IF;

  -- Refund wallet
  IF v_order.deposit_amount > 0 THEN
    UPDATE public.user_wallets SET deposit_wallet = deposit_wallet + v_order.deposit_amount WHERE user_id = v_order.user_id;
    v_ref := 'shop_refund_' || p_order_id;
    INSERT INTO public.wallet_transactions (user_id, amount, type, wallet_type, status, reference_id)
    VALUES (v_order.user_id, v_order.deposit_amount, 'deposit', 'deposit', 'completed', v_ref);
  END IF;

  IF v_order.winning_amount > 0 THEN
    UPDATE public.user_wallets SET winning_wallet = winning_wallet + v_order.winning_amount WHERE user_id = v_order.user_id;
    v_ref := 'shop_refund_' || p_order_id;
    INSERT INTO public.wallet_transactions (user_id, amount, type, wallet_type, status, reference_id)
    VALUES (v_order.user_id, v_order.winning_amount, 'deposit', 'winning', 'completed', v_ref);
  END IF;

  -- Update order status
  UPDATE public.shop_orders
  SET status = 'cancelled',
      updated_at = timezone('utc'::text, now())
  WHERE id = p_order_id;

  RETURN jsonb_build_object('success', true, 'message', 'Order cancelled and refunded');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4) Grants
GRANT EXECUTE ON FUNCTION public.purchase_shop_product(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.purchase_shop_product(UUID, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.cancel_shop_order(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_shop_order(UUID) TO service_role;

