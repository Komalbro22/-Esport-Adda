-- Add information fields to tournaments
ALTER TABLE public.tournaments 
ADD COLUMN IF NOT EXISTS rules TEXT,
ADD COLUMN IF NOT EXISTS map_name TEXT,
ADD COLUMN IF NOT EXISTS mode TEXT;

-- Add sorting capability to games
ALTER TABLE public.games 
ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;
