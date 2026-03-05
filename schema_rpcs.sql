-- Append to existing schema.sql

-- RPC functions for secure Edge Function invocation

create or replace function public.increment_joined_slots(tourney_id uuid)
returns void as $$
begin
  update public.tournaments
  set joined_slots = joined_slots + 1
  where id = tourney_id;
end;
$$ language plpgsql security definer;

create or replace function public.increment_deposit_wallet(u_id uuid, amt numeric)
returns void as $$
begin
  update public.user_wallets
  set deposit_wallet = deposit_wallet + amt
  where user_id = u_id;
end;
$$ language plpgsql security definer;

create or replace function public.increment_winning_wallet(u_id uuid, amt numeric)
returns void as $$
begin
  update public.user_wallets
  set winning_wallet = winning_wallet + amt
  where user_id = u_id;
end;
$$ language plpgsql security definer;

create or replace function public.decrement_winning_wallet(u_id uuid, amt numeric)
returns void as $$
begin
  update public.user_wallets
  set winning_wallet = winning_wallet - amt
  where user_id = u_id and winning_wallet >= amt;
end;
$$ language plpgsql security definer;
