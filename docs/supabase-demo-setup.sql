-- Urban Ghost Hunter — Sprint 1 demo schema + seed
-- Run in Supabase → SQL Editor (once per project)

create extension if not exists "uuid-ossp";

-- Hotspots shown on the map
create table if not exists public.hotspots (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  lat double precision not null,
  lng double precision not null,
  radius_m integer not null default 80,
  difficulty integer not null default 1,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Containment results
create table if not exists public.encounters (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null,
  hotspot_id uuid not null references public.hotspots(id) on delete cascade,
  outcome text not null,
  rewards_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.hotspots enable row level security;
alter table public.encounters enable row level security;

-- Hotspots: anyone signed in can read active hotspots
drop policy if exists "hotspots read" on public.hotspots;
create policy "hotspots read" on public.hotspots
  for select to authenticated
  using (active = true);

-- Encounters: read/write own rows only
drop policy if exists "encounters read own" on public.encounters;
create policy "encounters read own" on public.encounters
  for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "encounters insert own" on public.encounters;
create policy "encounters insert own" on public.encounters
  for insert to authenticated
  with check (auth.uid() = user_id);

-- Demo hotspot near Amsterdam (change lat/lng to your simulator custom location)
insert into public.hotspots (name, lat, lng, radius_m, difficulty, active)
select 'Demo Haunt', 52.3676, 4.9041, 500, 1, true
where not exists (
  select 1 from public.hotspots where name = 'Demo Haunt'
);
