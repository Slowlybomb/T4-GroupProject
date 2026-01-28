-- UUID generation and case-insensitive text extensions
create extension if not exists pgcrypto;
create extension if not exists citext;

-- 1) PROFILES
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username citext unique not null,
  display_name text,
  avatar_url text,
  bio text,
  created_at timestamptz not null default now()
);

-- 2) TEAMS
create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  name text not null,
  description text,
  avatar_url text,
  created_at timestamptz not null default now()
);

create index if not exists idx_teams_owner on public.teams(owner_id);

-- 2.1) TEAM MEMBERS (many-to-many)
create table if not exists public.team_members (
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member', -- owner/admin/member
  joined_at timestamptz not null default now(),
  primary key (team_id, user_id),
  constraint team_members_role_allowed check (role in ('owner', 'admin', 'member'))
);

create index if not exists idx_team_members_user on public.team_members(user_id);

-- 3) ACTIVITIES
-- visibility: private / followers / public / team
create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text,
  notes text,
  start_time timestamptz not null,
  duration_seconds int check (duration_seconds is null or duration_seconds >= 0),
  distance_m double precision check (distance_m is null or distance_m >= 0),
  avg_split_500m_seconds int check (avg_split_500m_seconds is null or avg_split_500m_seconds >= 0),
  avg_stroke_spm smallint check (avg_stroke_spm is null or avg_stroke_spm >= 0),
  visibility text not null default 'private'
    check (visibility in ('private', 'followers', 'public', 'team')),
  -- only used if visibility = 'team'
  team_id uuid references public.teams(id) on delete set null,
  -- GeoJSON LineString for map drawing (coordinates are [lng, lat]), can be null, https://www.postgresql.org/docs/current/datatype-json.html
  -- It appears that PostgreSQL has proper way to store JSON data, it is fast and efficient for storing.
  route_geojson jsonb,
  created_at timestamptz not null default now()
);

-- Indexes for common queries
create index if not exists idx_activities_user_time
  on public.activities(user_id, start_time desc);
create index if not exists idx_activities_team_time
  on public.activities(team_id, start_time desc);
create index if not exists idx_activities_visibility_time
  on public.activities(visibility, start_time desc);

-- Basic GeoJSON sanity check (keeps junk out)
alter table public.activities
  add constraint activities_route_geojson_linestring
  check (
    route_geojson is null
    or (
      jsonb_typeof(route_geojson) = 'object'
      and route_geojson->>'type' = 'LineString'
      and jsonb_typeof(route_geojson->'coordinates') = 'array'
    )
  );

-- If not team visibility, team_id should be null
alter table public.activities
  add constraint activities_team_id_only_for_team_visibility
  check (visibility = 'team' or team_id is null);

-- 3.1) ACTIVITY SAMPLES (time-series: speed + strokes per minute)
-- One row = measurements at a moment in the session.
-- Use offset since activity start. Clean ordering, easy charts.
create table if not exists public.activity_samples (
  activity_id uuid not null references public.activities(id) on delete cascade,
  t_offset_ms int not null check (t_offset_ms >= 0),

  -- metrics
  pace_500m_seconds int check (pace_500m_seconds is null or pace_500m_seconds >= 0),
  speed_mps real check (speed_mps is null or speed_mps >= 0),
  stroke_spm smallint check (stroke_spm is null or stroke_spm >= 0),

  -- optional sensor quality fields (keep now or remove)
  accuracy_m real check (accuracy_m is null or accuracy_m >= 0),

  created_at timestamptz not null default now(),

  primary key (activity_id, t_offset_ms)
);

-- PK already supports (activity_id, time) reads efficiently.
-- Extra index usually not needed unless you add other query patterns.

-- 4) FOLLOWS
create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followed_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  constraint follows_no_self check (follower_id <> followed_id)
);

create index if not exists idx_follows_follower
  on public.follows(follower_id);
create index if not exists idx_follows_followed on public.follows(followed_id);

-- 5) LIKES
create table if not exists public.activity_likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, activity_id)
);

create index if not exists idx_activity_likes_activity
  on public.activity_likes(activity_id);

-- 6) COMMENTS
create table if not exists public.activity_comments (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null references public.activities(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_activity_comments_activity_time
  on public.activity_comments(activity_id, created_at);

-- Ensure team owner is also a member (role = owner)
create or replace function public.add_team_owner_member()
returns trigger
language plpgsql
as $$
begin
  insert into public.team_members (team_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists trg_teams_add_owner_member on public.teams;
create trigger trg_teams_add_owner_member
after insert on public.teams
for each row execute function public.add_team_owner_member();

-- RLS: activity visibility (private/followers/team/public)
alter table public.activities enable row level security;

drop policy if exists activities_select_visibility on public.activities;
create policy activities_select_visibility on public.activities
for select
using (
  user_id = auth.uid()
  or visibility = 'public'
  or (
    visibility = 'followers'
    and exists (
      select 1
      from public.follows f
      where f.follower_id = auth.uid()
        and f.followed_id = public.activities.user_id
    )
  )
  or (
    visibility = 'team'
    and exists (
      select 1
      from public.team_members tm
      where tm.team_id = public.activities.team_id
        and tm.user_id = auth.uid()
    )
  )
);

drop policy if exists activities_insert_own on public.activities;
create policy activities_insert_own on public.activities
for insert
with check (user_id = auth.uid());

drop policy if exists activities_update_own on public.activities;
create policy activities_update_own on public.activities
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists activities_delete_own on public.activities;
create policy activities_delete_own on public.activities
for delete
using (user_id = auth.uid());
