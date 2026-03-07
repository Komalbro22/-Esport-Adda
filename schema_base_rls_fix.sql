-- ============================================================
-- Esport Adda — Admin RLS Fixes (Super Admin Support)
-- Run in Supabase SQL Editor
-- ============================================================

-- 1. Help function for admin check
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = user_id AND role IN ('admin', 'super_admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Update users table policies
DROP POLICY IF EXISTS "Admins can do everything on users" ON public.users;
CREATE POLICY "Admins can do everything on users" ON public.users 
  USING (public.is_admin(auth.uid()));

-- 3. Update user_wallets table policies
DROP POLICY IF EXISTS "Admins can do everything on user_wallets" ON public.user_wallets;
CREATE POLICY "Admins can do everything on user_wallets" ON public.user_wallets
  USING (public.is_admin(auth.uid()));

-- 4. Correct games table policies (Missing Admin policies)
DROP POLICY IF EXISTS "Admins can manage games" ON public.games;
CREATE POLICY "Admins can manage games" ON public.games
  FOR ALL USING (public.is_admin(auth.uid()));

-- 5. Correct tournaments table policies (Missing Admin policies)
DROP POLICY IF EXISTS "Admins can manage tournaments" ON public.tournaments;
CREATE POLICY "Admins can manage tournaments" ON public.tournaments
  FOR ALL USING (public.is_admin(auth.uid()));

-- 6. Update wallet_transactions table policies
DROP POLICY IF EXISTS "Admins can do everything on wallet_transactions" ON public.wallet_transactions;
CREATE POLICY "Admins can do everything on wallet_transactions" ON public.wallet_transactions
  USING (public.is_admin(auth.uid()));

-- 7. Update deposit_requests table policies
DROP POLICY IF EXISTS "Admins can do everything on deposit_requests" ON public.deposit_requests;
CREATE POLICY "Admins can do everything on deposit_requests" ON public.deposit_requests
  USING (public.is_admin(auth.uid()));

-- 8. Update withdraw_requests table policies
DROP POLICY IF EXISTS "Admins can do everything on withdraw_requests" ON public.withdraw_requests;
CREATE POLICY "Admins can do everything on withdraw_requests" ON public.withdraw_requests
  USING (public.is_admin(auth.uid()));

-- 9. Update admin_assets table policies
DROP POLICY IF EXISTS "Admins can insert assets." ON public.admin_assets;
CREATE POLICY "Admins can insert assets." ON public.admin_assets 
  FOR INSERT WITH CHECK (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Admins can delete assets." ON public.admin_assets;
CREATE POLICY "Admins can delete assets." ON public.admin_assets 
  FOR DELETE USING (public.is_admin(auth.uid()));
