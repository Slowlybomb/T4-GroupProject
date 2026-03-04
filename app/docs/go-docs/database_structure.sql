-- Supabase Database structure.

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
  -- GeoJSON LineString for map drawing (coordinates are [lng, lat]), can be null [https://wxww.postgresql.org/docs/current/datatype-json.html]
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

-- 3.1) ACTIVITY SAMPLES (raw stroke events)
-- One row = one stroke timestamp and cumulative distance.
create table if not exists public.activity_samples (
  activity_id uuid not null references public.activities(id) on delete cascade,
  stroke_timestamp_ms bigint not null check (stroke_timestamp_ms >= 0),
  distance_m double precision not null check (distance_m >= 0),

  created_at timestamptz not null default now(),

  primary key (activity_id, stroke_timestamp_ms)
);

-- Derive activity-level aggregates directly from raw stroke samples.
create or replace function public.recompute_activity_metrics_from_samples(p_activity_id uuid)
returns void
language plpgsql
as $$
declare
  v_min_ts bigint;
  v_max_ts bigint;
  v_stroke_count integer;
  v_distance_m double precision;
  v_elapsed_ms bigint;
  v_duration_seconds integer;
  v_avg_split_500m_seconds integer;
  v_avg_stroke_spm smallint;
begin
  select
    min(stroke_timestamp_ms),
    max(stroke_timestamp_ms),
    count(*)::int,
    max(distance_m)
  into
    v_min_ts,
    v_max_ts,
    v_stroke_count,
    v_distance_m
  from public.activity_samples
  where activity_id = p_activity_id;

  v_elapsed_ms := null;
  v_duration_seconds := null;
  v_avg_split_500m_seconds := null;
  v_avg_stroke_spm := null;

  if v_stroke_count >= 2 and v_min_ts is not null and v_max_ts is not null then
    v_elapsed_ms := greatest(v_max_ts - v_min_ts, 0);
    v_duration_seconds := round(v_elapsed_ms::numeric / 1000.0)::int;

    if v_elapsed_ms > 0 then
      v_avg_stroke_spm := least(
        round(((v_stroke_count - 1)::numeric * 60000.0) / v_elapsed_ms)::int,
        32767
      )::smallint;
    end if;
  end if;

  if v_elapsed_ms is not null and v_elapsed_ms > 0 and v_distance_m is not null and v_distance_m > 0 then
    v_avg_split_500m_seconds := round(((v_elapsed_ms::numeric / 1000.0) * 500.0) / v_distance_m)::int;
  end if;

  update public.activities
  set
    duration_seconds = v_duration_seconds,
    distance_m = v_distance_m,
    avg_split_500m_seconds = v_avg_split_500m_seconds,
    avg_stroke_spm = v_avg_stroke_spm
  where id = p_activity_id;
end;
$$;

create or replace function public.activity_samples_refresh_activity_metrics()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    perform public.recompute_activity_metrics_from_samples(old.activity_id);
    return old;
  end if;

  perform public.recompute_activity_metrics_from_samples(new.activity_id);

  if tg_op = 'UPDATE' and old.activity_id is distinct from new.activity_id then
    perform public.recompute_activity_metrics_from_samples(old.activity_id);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_activity_samples_refresh_activity_metrics on public.activity_samples;
create trigger trg_activity_samples_refresh_activity_metrics
after insert or update or delete on public.activity_samples
for each row execute function public.activity_samples_refresh_activity_metrics();

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
