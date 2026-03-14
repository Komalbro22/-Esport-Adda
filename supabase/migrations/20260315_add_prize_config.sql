-- Migration to support Fixed/Dynamic prize pools in tournaments
ALTER TABLE tournaments 
ADD COLUMN IF NOT EXISTS prize_type TEXT DEFAULT 'fixed',
ADD COLUMN IF NOT EXISTS commission_percentage DOUBLE PRECISION DEFAULT 10,
ADD COLUMN IF NOT EXISTS rank_percentages JSONB;

COMMENT ON COLUMN tournaments.prize_type IS 'Type of prize pool: fixed or dynamic';
COMMENT ON COLUMN tournaments.commission_percentage IS 'Percentage taken by the platform for dynamic prize pools';
COMMENT ON COLUMN tournaments.rank_percentages IS 'JSON map of rank to percentage (e.g. {"1": 50, "2": 30}) for dynamic prizes';

-- Ensure existing tournaments have a default value
UPDATE tournaments SET prize_type = 'fixed' WHERE prize_type IS NULL;
UPDATE tournaments SET commission_percentage = 10 WHERE commission_percentage IS NULL;
