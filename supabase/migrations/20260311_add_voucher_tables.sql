-- Create voucher_categories table
CREATE TABLE IF NOT EXISTS public.voucher_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    icon_url TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create voucher_amounts table
CREATE TABLE IF NOT EXISTS public.voucher_amounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES public.voucher_categories(id) ON DELETE CASCADE NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(category_id, amount)
);

-- Create voucher_codes table
CREATE TABLE IF NOT EXISTS public.voucher_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id UUID REFERENCES public.voucher_categories(id) ON DELETE CASCADE NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    voucher_code TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'reserved', 'used')),
    used_by UUID REFERENCES public.users(id),
    used_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create voucher_withdraw_requests table
CREATE TABLE IF NOT EXISTS public.voucher_withdraw_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) NOT NULL,
    category_id UUID REFERENCES public.voucher_categories(id) NOT NULL,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'rejected')),
    voucher_code TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_voucher_codes_lookup ON public.voucher_codes(category_id, amount, status);
CREATE INDEX IF NOT EXISTS idx_voucher_withdraw_requests_user ON public.voucher_withdraw_requests(user_id);

-- Enable RLS
ALTER TABLE public.voucher_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voucher_amounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voucher_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voucher_withdraw_requests ENABLE ROW LEVEL SECURITY;

-- -------------------------------------------------------------------------
-- Policies for voucher_categories
-- -------------------------------------------------------------------------

-- Public read access to active categories
CREATE POLICY "Allow authenticated read access to active categories"
    ON public.voucher_categories
    FOR SELECT
    TO authenticated
    USING (status = 'active' OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin')));

-- Admin all access
CREATE POLICY "Allow admin all access to voucher_categories"
    ON public.voucher_categories
    FOR ALL
    TO authenticated
    USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin')))
    WITH CHECK (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin')));

-- -------------------------------------------------------------------------
-- Policies for voucher_amounts
-- -------------------------------------------------------------------------

-- Public read access to active amounts
CREATE POLICY "Allow authenticated read access to active amounts"
    ON public.voucher_amounts
    FOR SELECT
    TO authenticated
    USING (status = 'active' OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin')));

-- Admin all access
CREATE POLICY "Allow admin all access to voucher_amounts"
    ON public.voucher_amounts
    FOR ALL
    TO authenticated
    USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin')))
    WITH CHECK (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin')));

-- -------------------------------------------------------------------------
-- Policies for voucher_codes
-- -------------------------------------------------------------------------

-- Users can read their own used codes
CREATE POLICY "Allow users to read their own voucher codes"
    ON public.voucher_codes
    FOR SELECT
    TO authenticated
    USING (used_by = auth.uid() OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin')));

-- Admin all access
CREATE POLICY "Allow admin all access to voucher_codes"
    ON public.voucher_codes
    FOR ALL
    TO authenticated
    USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin')))
    WITH CHECK (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin')));

-- edge functions bypass RLS as they use service role keys. 

-- -------------------------------------------------------------------------
-- Policies for voucher_withdraw_requests
-- -------------------------------------------------------------------------

-- Users can read their own requests
CREATE POLICY "Allow users to read their own requests"
    ON public.voucher_withdraw_requests
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin')));

-- Admin all access
CREATE POLICY "Allow admin all access to voucher_withdraw_requests"
    ON public.voucher_withdraw_requests
    FOR ALL
    TO authenticated
    USING (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin')))
    WITH CHECK (EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role IN ('admin', 'super_admin')));

