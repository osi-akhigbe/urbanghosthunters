-- add_totems_table
create table if not exists public.totems (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  bonus_type text,
  bonus_value float,
  rarity text,
  created_at timestamptz default now()
);

create table if not exists public.user_totems (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade,
  totem_id uuid references public.totems(id),
  totem_name text not null,
  equipped boolean default false,
  created_at timestamptz default now()
);

alter table public.user_totems enable row level security;

create policy "Users see own totems" on public.user_totems
  for all using (auth.uid() = user_id);