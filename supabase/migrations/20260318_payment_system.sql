create table public.payment_settings (
  id uuid primary key default gen_random_uuid(),
  active_method text check (active_method in ('manual_upi', 'razorpay')) default 'manual_upi',
  razorpay_key_id text,
  razorpay_secret_key text,
  razorpay_webhook_secret text,
  is_test_mode boolean default true,
  min_deposit numeric default 10,
  commission_percentage numeric default 0,
  upi_id text,
  upi_name text,
  upi_qr_url text,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Insert default settings
insert into public.payment_settings (active_method, is_test_mode, min_deposit, upi_name)
values ('manual_upi', true, 10, 'Esport Adda Admin');

-- 3. RLS for payment_settings (Admin ONLY)
alter table public.payment_settings enable row level security;
create policy "Admins can manage payment settings" on public.payment_settings
  using (exists (select 1 from public.users where id = auth.uid() and role = 'admin'));

-- 4. Secure RPC to fetch active settings for users WITHOUT exposing secret_key
create or replace function public.get_active_payment_method()
returns jsonb
language plpgsql
security definer
as $$
declare
  settings record;
  result jsonb;
begin
  select active_method, razorpay_key_id, is_test_mode, min_deposit, upi_id, upi_name, upi_qr_url 
  into settings from public.payment_settings limit 1;
  
  result := jsonb_build_object(
    'active_method', settings.active_method,
    'razorpay_key_id', settings.razorpay_key_id,
    'is_test_mode', settings.is_test_mode,
    'min_deposit', settings.min_deposit,
    'upi_id', settings.upi_id,
    'upi_name', settings.upi_name,
    'upi_qr_url', settings.upi_qr_url
  );
  
  return result;
end;
$$;

-- 5. Create razorpay_transactions table (to prevent duplicates and track order status)
create table public.razorpay_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete cascade,
  order_id text unique not null,
  payment_id text unique,
  signature text,
  amount numeric not null,
  status text check (status in ('created', 'captured', 'failed')) default 'created',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

alter table public.razorpay_transactions enable row level security;
-- Allow users to see their own transactions
create policy "Users can view their own razorpay transactions" on public.razorpay_transactions
  for select using (auth.uid() = user_id);
-- Allow edge functions to insert/update (via Service Role)
