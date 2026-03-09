-- Comprehensive Admin RLS Fix
-- This script ensures admins can manage tournaments and joined teams

-- 1. Tournaments
alter table public.tournaments enable row level security;
drop policy if exists "Admins can do everything on tournaments" on public.tournaments;
create policy "Admins can do everything on tournaments" on public.tournaments
  using (exists (select 1 from public.users where id = auth.uid() and role in ('admin', 'super_admin')));

-- 2. Joined Teams (Result Saving)
alter table public.joined_teams enable row level security;
drop policy if exists "Admins can do everything on joined_teams" on public.joined_teams;
create policy "Admins can do everything on joined_teams" on public.joined_teams
  using (exists (select 1 from public.users where id = auth.uid() and role in ('admin', 'super_admin')));

-- 3. Games
alter table public.games enable row level security;
drop policy if exists "Admins can do everything on games" on public.games;
create policy "Admins can do everything on games" on public.games
  using (exists (select 1 from public.users where id = auth.uid() and role in ('admin', 'super_admin')));

-- 4. Transactions (Force allow admin management)
alter table public.wallet_transactions enable row level security;
drop policy if exists "Admins can manage all transactions" on public.wallet_transactions;
create policy "Admins can manage all transactions" on public.wallet_transactions
  using (exists (select 1 from public.users where id = auth.uid() and role in ('admin', 'super_admin')));

-- 5. Deposit Requests
alter table public.deposit_requests enable row level security;
drop policy if exists "Admins can manage all deposit requests" on public.deposit_requests;
create policy "Admins can manage all deposit requests" on public.deposit_requests
  using (exists (select 1 from public.users where id = auth.uid() and role in ('admin', 'super_admin')));
