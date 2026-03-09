-- Add explicit RLS policy for admins to update joined_teams
create policy "Admins can update joined_teams" on public.joined_teams
  for update using (exists (select 1 from public.users where id = auth.uid() and role in ('admin', 'super_admin')));

create policy "Admins can insert joined_teams" on public.joined_teams
  for insert with check (exists (select 1 from public.users where id = auth.uid() and role in ('admin', 'super_admin')));

create policy "Admins can delete joined_teams" on public.joined_teams
  for delete using (exists (select 1 from public.users where id = auth.uid() and role in ('admin', 'super_admin')));
