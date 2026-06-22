-- Sprint 2: totems, inventory, journal joins
-- Run after supabase-demo-setup.sql

create table if not exists public.totems (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  description text not null default '',
  bonus_type text not null default 'shield',
  created_at timestamptz not null default now()
);

create table if not exists public.user_totems (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null,
  totem_id uuid not null references public.totems(id) on delete cascade,
  equipped boolean not null default false,
  acquired_at timestamptz not null default now(),
  unique (user_id, totem_id)
);

alter table public.totems enable row level security;
alter table public.user_totems enable row level security;

drop policy if exists "totems read" on public.totems;
create policy "totems read" on public.totems
  for select to authenticated using (true);

drop policy if exists "user_totems read own" on public.user_totems;
create policy "user_totems read own" on public.user_totems
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "user_totems insert own" on public.user_totems;
create policy "user_totems insert own" on public.user_totems
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "user_totems update own" on public.user_totems;
create policy "user_totems update own" on public.user_totems
  for update to authenticated using (auth.uid() = user_id);

-- Seed totems
insert into public.totems (name, description, bonus_type)
select 'Spirit Ward', '+15 shield during containment', 'shield'
where not exists (select 1 from public.totems where name = 'Spirit Ward');

insert into public.totems (name, description, bonus_type)
select 'Echo Lure', '+10% mic reveal chance', 'lure'
where not exists (select 1 from public.totems where name = 'Echo Lure');

-- Optional: higher difficulty demo hotspots
insert into public.hotspots (name, lat, lng, radius_m, difficulty, active)
select 'Hard Haunt', 52.3700, 4.9100, 400, 3, true
where not exists (select 1 from public.hotspots where name = 'Hard Haunt');
