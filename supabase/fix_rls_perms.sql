-- Run this in your Supabase SQL Editor to fix the RLS permissions

-- 1. Fix Users Table RLS
-- Allow users to view their own profile
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

-- Allow everyone to view other users (needed for leaderboards/opponent info)
DROP POLICY IF EXISTS "Anyone can view user profiles" ON public.users;
CREATE POLICY "Anyone can view user profiles" ON public.users
    FOR SELECT USING (true);

-- Allow users to insert their own profile during signup
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
CREATE POLICY "Users can insert own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Allow users to update their own profile
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);


-- 2. Fix User Wallets RLS
-- Allow users to view their own wallet
DROP POLICY IF EXISTS "Users can view own wallet" ON public.user_wallets;
CREATE POLICY "Users can view own wallet" ON public.user_wallets
    FOR SELECT USING (auth.uid() = user_id);

-- Allow users to insert their own wallet during signup
DROP POLICY IF EXISTS "Users can insert own wallet" ON public.user_wallets;
CREATE POLICY "Users can insert own wallet" ON public.user_wallets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 3. Fix Wallet Transactions RLS (to see history)
DROP POLICY IF EXISTS "Users can view own transactions" ON public.wallet_transactions;
CREATE POLICY "Users can view own transactions" ON public.wallet_transactions
    FOR SELECT USING (auth.uid() = user_id);
