-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. users
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  username text unique,
  phone text,
  avatar_url text,
  role text check (role in ('player', 'admin')) default 'player',
  is_blocked boolean default false,
  referral_code text unique,
  referred_by text,
  fcm_token text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. user_wallets
create table public.user_wallets (
  user_id uuid primary key references public.users(id) on delete cascade,
  deposit_wallet numeric default 0,
  winning_wallet numeric default 0,
  total_kills integer default 0,
  total_wins integer default 0,
  matches_played integer default 0,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 3. games
create table public.games (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text,
  logo_url text,
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 4. tournaments
create table public.tournaments (
  id uuid primary key default uuid_generate_v4(),
  game_id uuid references public.games(id) on delete restrict,
  title text not null,
  description text,
  banner_url text,
  entry_fee numeric not null default 0,
  total_slots integer not null,
  joined_slots integer default 0,
  per_kill_reward numeric not null default 0,
  tournament_type text check (tournament_type in ('solo', 'duo', 'squad')) not null,
  status text check (status in ('upcoming', 'ongoing', 'completed')) default 'upcoming',
  start_time timestamp with time zone,
  room_id text,
  room_password text,
  rank_prizes jsonb,
  prize_description text,
  created_by uuid references public.users(id),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 5. joined_teams
create table public.joined_teams (
  id uuid primary key default uuid_generate_v4(),
  tournament_id uuid references public.tournaments(id) on delete cascade,
  user_id uuid references public.users(id),
  team_data jsonb,
  rank integer,
  kills integer default 0,
  total_prize numeric default 0,
  is_prize_distributed boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 6. wallet_transactions
create table public.wallet_transactions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  amount numeric not null,
  type text check (type in ('deposit', 'withdraw', 'tournament_entry', 'tournament_win', 'referral_bonus')) not null,
  wallet_type text check (wallet_type in ('deposit', 'winning')) not null,
  status text check (status in ('pending', 'approved', 'rejected', 'completed')) not null,
  reference_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 7. deposit_requests
create table public.deposit_requests (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  amount numeric not null,
  upi_id text,
  screenshot_url text not null,
  status text check (status in ('pending', 'approved', 'rejected')) default 'pending',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 8. withdraw_requests
create table public.withdraw_requests (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  amount numeric not null,
  upi_id text not null,
  status text check (status in ('pending', 'approved', 'rejected')) default 'pending',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  processed_at timestamp with time zone
);

-- 9. notifications
create table public.notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references public.users(id) on delete cascade,
  title text not null,
  body text not null,
  is_read boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 10. admin_assets (For Image Gallery)
create table public.admin_assets (
  id uuid primary key default uuid_generate_v4(),
  name text,
  url text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Create a trigger function to handle user metadata into public users table
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.users (id, email, name, role)
  values (new.id, new.email, new.raw_user_meta_data->>'name', coalesce(new.raw_user_meta_data->>'role', 'player'));

  insert into public.user_wallets (user_id) values (new.id);
  
  return new;
end;
$$ language plpgsql security definer;

-- Trigger to hook into auth.users insert
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Establish read access using RLS for user access control (example base layer)
alter table public.users enable row level security;
alter table public.user_wallets enable row level security;
alter table public.games enable row level security;
alter table public.tournaments enable row level security;
alter table public.joined_teams enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.deposit_requests enable row level security;
alter table public.withdraw_requests enable row level security;
alter table public.notifications enable row level security;

-- Base permissive RLS policies for immediate prototyping (can be tightened later in edge functions)
create policy "Public users are viewable by everyone." on public.users for select using (true);
create policy "Users can update their own profile." on public.users for update using (auth.uid() = id);

create policy "Users can view their wallet." on public.user_wallets for select using (auth.uid() = user_id);

create policy "Games viewable by everyone." on public.games for select using (true);

create policy "Tournaments viewable by everyone." on public.tournaments for select using (true);

create policy "Joined teams viewable by everyone." on public.joined_teams for select using (true);

create policy "Users can view their own wallet transactions." on public.wallet_transactions for select using (auth.uid() = user_id);

create policy "Users can insert their own deposit requests." on public.deposit_requests for insert with check (auth.uid() = user_id);
create policy "Users can view their own deposit requests." on public.deposit_requests for select using (auth.uid() = user_id);

create policy "Users can insert their own withdraw requests." on public.withdraw_requests for insert with check (auth.uid() = user_id);
create policy "Users can view their own withdraw requests." on public.withdraw_requests for select using (auth.uid() = user_id);

create policy "Users can view their own notifications." on public.notifications for select using (auth.uid() = user_id or user_id is null);
create policy "Users can update their own notifications." on public.notifications for update using (auth.uid() = user_id);

-- Admin Policies
create policy "Admins can do everything on users" on public.users 
  using (exists (select 1 from public.users where id = auth.uid() and role = 'admin'));

create policy "Admins can do everything on user_wallets" on public.user_wallets
  using (exists (select 1 from public.users where id = auth.uid() and role = 'admin'));

create policy "Admins can do everything on wallet_transactions" on public.wallet_transactions
  using (exists (select 1 from public.users where id = auth.uid() and role = 'admin'));

create policy "Admins can do everything on deposit_requests" on public.deposit_requests
  using (exists (select 1 from public.users where id = auth.uid() and role = 'admin'));

create policy "Admins can do everything on withdraw_requests" on public.withdraw_requests
  using (exists (select 1 from public.users where id = auth.uid() and role = 'admin'));

alter table public.admin_assets enable row level security;
create policy "Admin assets are viewable by everyone." on public.admin_assets for select using (true);
create policy "Admins can insert assets." on public.admin_assets for insert with check (
  exists (select 1 from public.users where id = auth.uid() and role = 'admin')
);
create policy "Admins can delete assets." on public.admin_assets for delete using (
  exists (select 1 from public.users where id = auth.uid() and role = 'admin')
);

-- Note: Edge functions will bypass RLS because they use the Service Role Key.
-- Admin dashboard access policies can be bound to user role = 'admin'.
