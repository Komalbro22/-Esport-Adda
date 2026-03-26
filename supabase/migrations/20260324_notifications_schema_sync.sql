-- Sync notifications schema for compatibility
-- Handles both:
-- - modern schema: title + message + type + reference_id
-- - legacy schema: title + body

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS message text;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS body text;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS type text;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS reference_id text;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS is_read boolean DEFAULT false;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- Backfill message/body if one of them exists
UPDATE public.notifications
SET message = body
WHERE (message IS NULL OR message = '') AND body IS NOT NULL;

UPDATE public.notifications
SET body = message
WHERE (body IS NULL OR body = '') AND message IS NOT NULL;

-- Backfill type
UPDATE public.notifications
SET type = 'admin_push'
WHERE type IS NULL OR type = '';

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

