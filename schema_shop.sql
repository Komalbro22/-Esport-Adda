-- 1. Add global settings for shop to app_settings
ALTER TABLE public.app_settings 
ADD COLUMN IF NOT EXISTS default_shop_wallet_type text DEFAULT 'both' CHECK (default_shop_wallet_type IN ('deposit', 'winning', 'both'));

-- 2. Create shop_products
CREATE TABLE IF NOT EXISTS public.shop_products (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  description text,
  image_url text,
  price numeric NOT NULL,
  category text,
  is_digital boolean DEFAULT true,
  allowed_wallet_type text CHECK (allowed_wallet_type IN ('deposit', 'winning', 'both', 'global')) DEFAULT 'global',
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. Create shop_orders
CREATE TABLE IF NOT EXISTS public.shop_orders (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
  product_id uuid REFERENCES public.shop_products(id) ON DELETE SET NULL,
  amount numeric NOT NULL,
  paid_from text CHECK (paid_from IN ('deposit', 'winning', 'both')),
  status text CHECK (status IN ('pending', 'completed', 'cancelled')) DEFAULT 'pending',
  delivery_data text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. RPC for purchasing a product safely.
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

  -- Record wallet transactions (we use withdraw type but maybe should add a shop_purchase enum later, for now withdraw is safe)
  -- 'wallet_transactions.type' check constraint expects 'withdraw'
  IF v_deposit_deducted > 0 THEN
    INSERT INTO public.wallet_transactions (user_id, amount, type, wallet_type, status, reference_id)
    VALUES (p_user_id, v_deposit_deducted, 'withdraw', 'deposit', 'completed', 'shop_purchase_' || p_product_id);
  END IF;

  IF v_winning_deducted > 0 THEN
    INSERT INTO public.wallet_transactions (user_id, amount, type, wallet_type, status, reference_id)
    VALUES (p_user_id, v_winning_deducted, 'withdraw', 'winning', 'completed', 'shop_purchase_' || p_product_id);
  END IF;

  -- Create Order
  INSERT INTO public.shop_orders (user_id, product_id, amount, paid_from, status)
  VALUES (p_user_id, p_product_id, v_to_deduct, v_paid_from, 'pending')
  RETURNING id INTO v_order_id;

  RETURN jsonb_build_object('success', true, 'message', 'Purchase successful', 'order_id', v_order_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RLS Policies
ALTER TABLE public.shop_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_orders ENABLE ROW LEVEL SECURITY;

-- Products
DROP POLICY IF EXISTS "Products are viewable by everyone" ON public.shop_products;
CREATE POLICY "Products are viewable by everyone" ON public.shop_products FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can do everything on shop_products" ON public.shop_products;
CREATE POLICY "Admins can do everything on shop_products" ON public.shop_products
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND (role = 'admin' OR role = 'super_admin')));

-- Orders
DROP POLICY IF EXISTS "Users can view their own orders" ON public.shop_orders;
CREATE POLICY "Users can view their own orders" ON public.shop_orders FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admins can do everything on shop_orders" ON public.shop_orders;
CREATE POLICY "Admins can do everything on shop_orders" ON public.shop_orders
  FOR ALL
  USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND (role = 'admin' OR role = 'super_admin')));

-- Grant execute to service_role and authenticated
GRANT EXECUTE ON FUNCTION public.purchase_shop_product(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.purchase_shop_product(UUID, UUID) TO service_role;
