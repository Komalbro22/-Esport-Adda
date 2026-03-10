-- Challenges and Fair Play System Migration

-- 1. Update existing tables
ALTER TABLE public.games 
ADD COLUMN IF NOT EXISTS challenge_enabled boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS challenge_commission_percent numeric DEFAULT 10,
ADD COLUMN IF NOT EXISTS challenge_min_entry_fee numeric DEFAULT 10,
ADD COLUMN IF NOT EXISTS challenge_modes jsonb DEFAULT '["1v1"]'::jsonb;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS fair_score integer DEFAULT 100;

-- 2. Create challenges table
CREATE TABLE IF NOT EXISTS public.challenges (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    game_id uuid REFERENCES public.games(id) ON DELETE RESTRICT,
    creator_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    opponent_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    players_joined integer DEFAULT 1 CHECK (players_joined <= 2),
    entry_fee numeric NOT NULL,
    mode text NOT NULL,
    rules text,
    settings text,
    min_fair_score integer DEFAULT 0,
    commission_percent numeric NOT NULL,
    status text NOT NULL CHECK (status IN ('open', 'accepted', 'ready', 'ongoing', 'completed', 'dispute', 'cancelled')),
    room_id text,
    room_password text,
    winner_id uuid REFERENCES public.users(id),
    result_locked boolean DEFAULT false,
    creator_ready boolean DEFAULT false,
    opponent_ready boolean DEFAULT false,
    accepted_at timestamp with time zone,
    room_ready_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_challenges_status ON public.challenges(status);
CREATE INDEX IF NOT EXISTS idx_challenges_game ON public.challenges(game_id);
CREATE INDEX IF NOT EXISTS idx_challenges_creator ON public.challenges(creator_id);
CREATE INDEX IF NOT EXISTS idx_challenges_opponent ON public.challenges(opponent_id);

-- 3. Create challenge_results table
CREATE TABLE IF NOT EXISTS public.challenge_results (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    challenge_id uuid REFERENCES public.challenges(id) ON DELETE CASCADE,
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    result text CHECK (result IN ('win', 'lose')),
    screenshot_url text,
    video_url text,
    screenshot_hash text,
    submitted_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(challenge_id, user_id)
);

-- 4. Create blocked_users table
CREATE TABLE IF NOT EXISTS public.blocked_users (
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    blocked_user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (user_id, blocked_user_id)
);

-- 5. Create fair_score_logs table
CREATE TABLE IF NOT EXISTS public.fair_score_logs (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    previous_score integer NOT NULL,
    new_score integer NOT NULL,
    change_reason text NOT NULL,
    actor_id uuid REFERENCES public.users(id), -- Null if system
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 6. Create fair_score_config table
CREATE TABLE IF NOT EXISTS public.fair_score_config (
    key text PRIMARY KEY,
    value integer NOT NULL,
    description text,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Initial fair score config
INSERT INTO public.fair_score_config (key, value, description) VALUES
('fake_result_claim', -20, 'Penalty for submitting fake win'),
('fake_deposit_request', -30, 'Penalty for fake payment proof'),
('leaving_challenge', -15, 'Penalty for abandoning ongoing match'),
('abusive_behavior', -10, 'Penalty for chat/behavior reported'),
('repeated_disputes', -5, 'Penalty for frequent disputes'),
('fair_match_completed', 1, 'Reward for honest match completion'),
('no_dispute_match', 2, 'Reward for match without any dispute'),
('recovery_reward', 3, 'Reward for 10 fair matches in a row')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 7. RLS Policies
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenge_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fair_score_logs ENABLE ROW LEVEL SECURITY;

-- Challenges: Everyone can see open/ongoing challenges (to join/watch), users can see their own.
CREATE POLICY "Challenges are viewable by everyone." ON public.challenges FOR SELECT USING (true);
CREATE POLICY "Users can create challenges." ON public.challenges FOR INSERT WITH CHECK (auth.uid() = creator_id);
CREATE POLICY "Admins can update challenges." ON public.challenges FOR ALL USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

-- Challenge Results: Participants and Admins can see.
CREATE POLICY "Participants can view results." ON public.challenge_results FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.challenges WHERE id = challenge_id AND (creator_id = auth.uid() OR opponent_id = auth.uid()))
    OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

-- Blocked Users: Only the user can manage their blocks.
CREATE POLICY "Users can manage their blocked list." ON public.blocked_users FOR ALL USING (auth.uid() = user_id);

-- Fair Score Logs: Users can see their own, admins see all.
CREATE POLICY "Users can view their fair score logs." ON public.fair_score_logs FOR SELECT USING (
    auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

-- 8. Wallet Transaction Types
-- Note: These types must be added to the check constraint of wallet_transactions.type
-- Since we can't easily alter enum/check constraints gracefully without knowing current state,
-- we'll assume the edge function handles it or provides a fallback.
-- In schema.sql, type was: check (type in ('deposit', 'withdraw', 'tournament_entry', 'tournament_win', 'referral_bonus'))
-- We need to add: 'challenge_entry', 'challenge_prize', 'challenge_refund', 'challenge_commission'

DO $$ 
BEGIN
    ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;
    ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_type_check 
    CHECK (type IN ('deposit', 'withdraw', 'tournament_entry', 'tournament_win', 'referral_bonus', 'challenge_entry', 'challenge_prize', 'challenge_refund', 'challenge_commission'));
END $$;
