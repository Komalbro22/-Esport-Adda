-- Migration: Add OneSignal support and notifications table

-- 1. Add OneSignal Player ID to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS onesignal_player_id TEXT;

-- 2. Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL, -- tournament, challenge, wallet, voucher, fair_play, admin, system
    reference_id TEXT, -- e.g. tournament_id or challenge_id
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Enable RLS on notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- 4. Create RLS policies for notifications
-- Users can only see their own notifications
CREATE POLICY "Users can view own notifications"
    ON notifications FOR SELECT
    USING (auth.uid() = user_id);

-- System/Admin can insert notifications (via service role usually, but we'll add a check)
CREATE POLICY "Users cannot insert notifications"
    ON notifications FOR INSERT
    WITH CHECK (false);

-- Users can update (mark as read) their own notifications
CREATE POLICY "Users can update own notifications"
    ON notifications FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 5. Create index for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
