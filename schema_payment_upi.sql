-- ============================================================
-- Payment Settings UPI Extension
-- Run in Supabase SQL Editor
-- ============================================================

-- Add new columns if they don't exist
ALTER TABLE public.payment_settings
  ADD COLUMN IF NOT EXISTS upi_name text,
  ADD COLUMN IF NOT EXISTS upi_qr_url text,
  ADD COLUMN IF NOT EXISTS minimum_deposit numeric DEFAULT 10;

-- Also add transaction_id to deposit_requests (for UPI reference)
ALTER TABLE public.deposit_requests
  ADD COLUMN IF NOT EXISTS transaction_id text;

-- Ensure upi_qr_url mirrors qr_code_url if both exist
UPDATE public.payment_settings
  SET upi_qr_url = qr_code_url
  WHERE upi_qr_url IS NULL AND qr_code_url IS NOT NULL;

-- Seed a default row if table is empty
INSERT INTO public.payment_settings (upi_id, upi_name, upi_qr_url, minimum_deposit)
SELECT 'esportadda@upi', 'Esport Adda', NULL, 10
WHERE NOT EXISTS (SELECT 1 FROM public.payment_settings);
