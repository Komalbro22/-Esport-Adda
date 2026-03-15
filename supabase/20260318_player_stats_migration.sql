-- 1. Create player_stats table
CREATE TABLE IF NOT EXISTS public.player_stats (
    user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    matches_played INTEGER DEFAULT 0,
    matches_won INTEGER DEFAULT 0,
    total_kills INTEGER DEFAULT 0,
    total_winnings NUMERIC DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Index for leaderboards (optimized search)
CREATE INDEX IF NOT EXISTS idx_player_stats_winnings ON public.player_stats (total_winnings DESC);

-- 2. Update schemas for robust functionality
ALTER TABLE public.wallet_transactions 
ADD COLUMN IF NOT EXISTS message TEXT,
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completed';

-- Ensure the 'tournament_win' and 'tournament_refund' types are in the CHECK constraint
DO $$ 
BEGIN
    ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_type_check;
    ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_type_check 
    CHECK (type IN ('deposit', 'withdraw', 'tournament_entry', 'tournament_win', 'referral_bonus', 'challenge_entry', 'challenge_prize', 'challenge_refund', 'challenge_commission', 'tournament_refund', 'other'));
EXCEPTION
    WHEN OTHERS THEN RAISE NOTICE 'Check constraint update failed, skipping if already correct';
END $$;

ALTER TABLE public.joined_teams 
ADD COLUMN IF NOT EXISTS fee_deposit NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS fee_winning NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_refunded BOOLEAN DEFAULT false;

-- 3. Migrate existing data if user_wallets has stats
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_wallets' AND column_name='matches_played') THEN
        INSERT INTO public.player_stats (user_id, matches_played, matches_won, total_kills)
        SELECT user_id, matches_played, total_wins, total_kills
        FROM public.user_wallets
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
END $$;

-- 4. Atomic Tournament Payout RPC
CREATE OR REPLACE FUNCTION public.process_tournament_payout(
    p_user_id UUID,
    p_tournament_id UUID,
    p_amount NUMERIC,
    p_rank INTEGER,
    p_kills INTEGER,
    p_tournament_title TEXT
)
RETURNS void AS $$
DECLARE
    v_is_win BOOLEAN;
BEGIN
    v_is_win := (p_rank = 1);

    -- 1. Update Winning Wallet
    INSERT INTO public.user_wallets (user_id, winning_wallet)
    VALUES (p_user_id, p_amount)
    ON CONFLICT (user_id) DO UPDATE
    SET winning_wallet = COALESCE(user_wallets.winning_wallet, 0) + p_amount,
        updated_at = timezone('utc'::text, now());

    -- 2. Log Transaction
    INSERT INTO public.wallet_transactions (
        user_id, 
        amount, 
        type, 
        wallet_type, 
        status, 
        reference_id,
        message
    )
    VALUES (
        p_user_id, 
        p_amount, 
        'tournament_win', 
        'winning', 
        'completed', 
        p_tournament_id::TEXT,
        'Won ₹' || p_amount || ' (Rank: ' || p_rank || ', Kills: ' || p_kills || ') in "' || p_tournament_title || '"'
    );

    -- 3. Update Player Stats
    INSERT INTO public.player_stats (user_id, matches_played, matches_won, total_kills, total_winnings)
    VALUES (p_user_id, 1, CASE WHEN v_is_win THEN 1 ELSE 0 END, p_kills, p_amount)
    ON CONFLICT (user_id) DO UPDATE
    SET matches_played = player_stats.matches_played + 1,
        matches_won = player_stats.matches_won + (CASE WHEN v_is_win THEN 1 ELSE 0 END),
        total_kills = player_stats.total_kills + p_kills,
        total_winnings = player_stats.total_winnings + p_amount,
        updated_at = timezone('utc'::text, now());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.process_tournament_payout(UUID, UUID, NUMERIC, INTEGER, INTEGER, TEXT) TO service_role;
