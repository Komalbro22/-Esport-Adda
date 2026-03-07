-- ============================================================
-- Esport Adda — Admin Permissions & Activity Logs Migration
-- Run once in Supabase SQL Editor
-- ============================================================

-- 1. Extend role CHECK to include super_admin
ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE public.users
  ADD CONSTRAINT users_role_check
  CHECK (role IN ('player', 'admin', 'super_admin'));

-- 2. admin_permissions table
CREATE TABLE IF NOT EXISTS public.admin_permissions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES public.users(id) ON DELETE CASCADE UNIQUE,
  can_manage_games boolean DEFAULT false,
  can_manage_tournaments boolean DEFAULT false,
  can_manage_results boolean DEFAULT false,
  can_manage_deposits boolean DEFAULT false,
  can_manage_withdrawals boolean DEFAULT false,
  can_manage_users boolean DEFAULT false,
  can_send_notifications boolean DEFAULT false,
  can_view_dashboard boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 3. admin_activity_logs table
CREATE TABLE IF NOT EXISTS public.admin_activity_logs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  admin_name text,
  action text NOT NULL,
  target_type text,
  target_id text,
  details jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. RLS for admin_permissions
ALTER TABLE public.admin_permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin reads own permissions" ON public.admin_permissions;
CREATE POLICY "Admin reads own permissions"
  ON public.admin_permissions FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Super admin full access to permissions" ON public.admin_permissions;
CREATE POLICY "Super admin full access to permissions"
  ON public.admin_permissions FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'super_admin')
  );

-- 5. RLS for admin_activity_logs
ALTER TABLE public.admin_activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Super admin can view all logs" ON public.admin_activity_logs;
CREATE POLICY "Super admin can view all logs"
  ON public.admin_activity_logs FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'super_admin')
  );

DROP POLICY IF EXISTS "Admins can insert logs" ON public.admin_activity_logs;
CREATE POLICY "Admins can insert logs"
  ON public.admin_activity_logs FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin'))
  );

