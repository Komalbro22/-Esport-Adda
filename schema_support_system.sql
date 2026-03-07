-- ============================================================
-- Support System FIX SCRIPT
-- RUN THIS IN SUPABASE SQL EDITOR
-- ============================================================

-- 1. Ensure Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Fix support_tickets table
-- If it exists but lacks columns, add them
DO $$ 
BEGIN 
  -- Add category if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_tickets' AND column_name='category') THEN
    ALTER TABLE public.support_tickets ADD COLUMN category text DEFAULT 'General';
  END IF;

  -- Add priority if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_tickets' AND column_name='priority') THEN
    ALTER TABLE public.support_tickets ADD COLUMN priority text DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high'));
  END IF;

  -- Add updated_at if missing
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_tickets' AND column_name='updated_at') THEN
    ALTER TABLE public.support_tickets ADD COLUMN updated_at timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL;
  END IF;

  -- Remove 'message' column from tickets if it exists (since it's moved to messages table)
  -- Or just leave it if you want, but my code doesn't send it. 
  -- If it's NOT NULL, we must make it NULLABLE.
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='support_tickets' AND column_name='message') THEN
    ALTER TABLE public.support_tickets ALTER COLUMN message DROP NOT NULL;
  END IF;
END $$;

-- 3. Ensure support_messages table exists
CREATE TABLE IF NOT EXISTS public.support_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid REFERENCES public.support_tickets(id) ON DELETE CASCADE,
  sender_id uuid REFERENCES public.users(id),
  message text,
  image_url text,
  sender_role text CHECK (sender_role IN ('player', 'admin', 'super_admin')),
  created_at timestamp with time zone DEFAULT timezone('utc', now()) NOT NULL
);

-- 4. Re-apply RLS and Policies (Safe to run multiple times)
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.support_messages ENABLE ROW LEVEL SECURITY;

-- Cleanup old policies to avoid "already exists" errors
DROP POLICY IF EXISTS "Users can view own tickets" ON public.support_tickets;
DROP POLICY IF EXISTS "Users can create own tickets" ON public.support_tickets;
DROP POLICY IF EXISTS "Admins can view all tickets" ON public.support_tickets;
DROP POLICY IF EXISTS "Admins can update all tickets" ON public.support_tickets;
DROP POLICY IF EXISTS "Super admin can delete tickets" ON public.support_tickets;

CREATE POLICY "Users can view own tickets" ON public.support_tickets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own tickets" ON public.support_tickets FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can view all tickets" ON public.support_tickets FOR SELECT USING (public.is_admin(auth.uid()));
CREATE POLICY "Admins can update all tickets" ON public.support_tickets FOR UPDATE USING (public.is_admin(auth.uid()));
CREATE POLICY "Super admin can delete tickets" ON public.support_tickets FOR DELETE USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Users can view messages in own tickets" ON public.support_messages;
DROP POLICY IF EXISTS "Users can insert messages in own tickets" ON public.support_messages;
DROP POLICY IF EXISTS "Admins can view all messages" ON public.support_messages;
DROP POLICY IF EXISTS "Admins can insert messages" ON public.support_messages;

CREATE POLICY "Users can view messages in own tickets" ON public.support_messages FOR SELECT USING (EXISTS (SELECT 1 FROM public.support_tickets WHERE id = ticket_id AND user_id = auth.uid()));
CREATE POLICY "Users can insert messages in own tickets" ON public.support_messages FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.support_tickets WHERE id = ticket_id AND user_id = auth.uid()));
CREATE POLICY "Admins can view all messages" ON public.support_messages FOR SELECT USING (public.is_admin(auth.uid()));
CREATE POLICY "Admins can insert messages" ON public.support_messages FOR INSERT WITH CHECK (public.is_admin(auth.uid()));

-- 5. Trigger
CREATE OR REPLACE FUNCTION update_ticket_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.support_tickets SET updated_at = now() WHERE id = NEW.ticket_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_support_message_sent ON public.support_messages;
CREATE TRIGGER on_support_message_sent
  AFTER INSERT ON public.support_messages
  FOR EACH ROW EXECUTE PROCEDURE update_ticket_timestamp();
