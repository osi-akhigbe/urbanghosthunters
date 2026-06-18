-- Profiles
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  handle text unique not null,
  created_at timestamptz default now()
);

-- Hotspots
create table hotspots (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  lat double precision not null,
  lng double precision not null,
  radius_m integer not null default 50,
  difficulty integer not null default 1,
  active boolean not null default true
);

-- Encounters
create table encounters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users on delete cascade not null,
  hotspot_id uuid references hotspots on delete cascade not null,
  started_at timestamptz default now(),
  captured_at timestamptz,
  outcome text,
  rewards_json jsonb
);

-- RLS
alter table profiles enable row level security;
alter table hotspots enable row level security;
alter table encounters enable row level security;

-- Policies
create policy "Users can read active hotspots"
  on hotspots for select
  using (active = true);

create policy "Users can read own encounters"
  on encounters for select
  using (auth.uid() = user_id);

create policy "Users can insert own encounters"
  on encounters for insert
  with check (auth.uid() = user_id);

create policy "Users can read own profile"
  on profiles for select
  using (auth.uid() = id);