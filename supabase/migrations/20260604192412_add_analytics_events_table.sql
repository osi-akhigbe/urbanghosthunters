-- add_analytics_events_table
create table if not exists public.events (
  id uuid default gen_random_uuid() primary key,
  type text not null,
  ts timestamptz default now(),
  user_id uuid references auth.users(id) on delete set null,
  metadata jsonb
);

alter table public.events enable row level security;

create policy "Users insert own events" on public.events
  for insert with check (auth.uid() = user_id);