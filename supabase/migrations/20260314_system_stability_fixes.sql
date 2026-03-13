-- Migration: System Stability Fixes, RLS Enhancements, and Activity Logging
-- Date: 2026-03-14

-- 0. Update Role constraint to include super_admin
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check CHECK (role IN ('player', 'admin', 'super_admin'));

-- 1. Consolidate Notifications Table Schema
-- Ensure 'message' is the standard column name, handles both 'body' and 'message' from various versions
DO $$ 
BEGIN
    -- If 'body' exists but 'message' doesn't, rename it
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notifications' AND column_name='body') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notifications' AND column_name='message') THEN
        ALTER TABLE public.notifications RENAME COLUMN body TO message;
    END IF;

    -- If both exist (rare), copy data and drop body
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notifications' AND column_name='body') 
       AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notifications' AND column_name='message') THEN
        UPDATE public.notifications SET message = body WHERE message IS NULL OR message = '';
        ALTER TABLE public.notifications DROP COLUMN body;
    END IF;
END $$;

-- 2. Grant super_admin and admin full access to critical tables
-- Function to check if user is admin or super_admin safely (breaks recursion)
CREATE OR REPLACE FUNCTION public.has_admin_access()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role IN ('admin', 'super_admin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update RLS policies for User Activity Logs
DROP POLICY IF EXISTS "Admins can view all logs" ON public.user_activity_logs;
DROP POLICY IF EXISTS "Admins and Super Admins can view all logs" ON public.user_activity_logs;
CREATE POLICY "Admins and Super Admins can view all logs"
  ON public.user_activity_logs FOR SELECT
  USING (public.has_admin_access());

-- Update RLS for Users table
DROP POLICY IF EXISTS "Admins can do everything on users" ON public.users;
DROP POLICY IF EXISTS "Admins/Super Admins can manage all users" ON public.users;
CREATE POLICY "Admins/Super Admins can manage all users" ON public.users 
  FOR ALL USING (public.has_admin_access());

-- Update RLS for Wallets
DROP POLICY IF EXISTS "Admins can do everything on user_wallets" ON public.user_wallets;
DROP POLICY IF EXISTS "Admins/Super Admins can manage all wallets" ON public.user_wallets;
CREATE POLICY "Admins/Super Admins can manage all wallets" ON public.user_wallets
  FOR ALL USING (public.has_admin_access());

-- 3. Unified Activity Logger Function
CREATE OR REPLACE FUNCTION public.log_user_activity(
    p_user_id uuid,
    p_activity_type text,
    p_description text,
    p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS void AS $$
BEGIN
    INSERT INTO public.user_activity_logs (user_id, activity_type, description, metadata)
    VALUES (p_user_id, p_activity_type, p_description, p_metadata);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Triggers for Automatic Activity Logging
-- Log profile updates
CREATE OR REPLACE FUNCTION public.on_user_profile_update_log()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.name IS DISTINCT FROM NEW.name OR OLD.username IS DISTINCT FROM NEW.username OR OLD.bio IS DISTINCT FROM NEW.bio) THEN
        INSERT INTO public.user_activity_logs (user_id, activity_type, description)
        VALUES (NEW.id, 'profile_edit', 'User updated their profile details');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_user_profile_update_log ON public.users;
CREATE TRIGGER tr_user_profile_update_log
  AFTER UPDATE ON public.users
  FOR EACH ROW EXECUTE PROCEDURE public.on_user_profile_update_log();

-- Log wallet transactions results
CREATE OR REPLACE FUNCTION public.on_wallet_transaction_log()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.status = 'completed') THEN
        INSERT INTO public.user_activity_logs (user_id, activity_type, description, metadata)
        VALUES (NEW.user_id, 'wallet_transaction', 
                format('%s of ₹%s (%s)', upper(NEW.type), NEW.amount, NEW.status),
                jsonb_build_object('amount', NEW.amount, 'type', NEW.type, 'tx_id', NEW.id));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_wallet_transaction_log ON public.wallet_transactions;
CREATE TRIGGER tr_wallet_transaction_log
  AFTER INSERT OR UPDATE ON public.wallet_transactions
  FOR EACH ROW EXECUTE PROCEDURE public.on_wallet_transaction_log();
