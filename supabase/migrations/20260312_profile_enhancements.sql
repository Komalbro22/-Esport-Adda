-- Add bio and social_links to users table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS bio TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS social_links JSONB DEFAULT '{}'::jsonb;

-- Ensure description exists in wallet_transactions (double checking from previous fix)
ALTER TABLE public.wallet_transactions 
ADD COLUMN IF NOT EXISTS description TEXT;
