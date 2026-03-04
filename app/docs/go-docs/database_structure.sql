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

-- Keep profiles in sync with new auth signups.
create or replace function public.create_profile_for_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
  v_display_name text;
begin
  v_username := 'user_' || replace(new.id::text, '-', '');
  v_display_name := nullif(trim(coalesce(new.raw_user_meta_data->>'full_name', '')), '');

  insert into public.profiles (id, username, display_name)
  values (new.id, v_username, v_display_name)
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_auth_users_create_profile on auth.users;
create trigger trg_auth_users_create_profile
after insert on auth.users
for each row
execute function public.create_profile_for_new_auth_user();

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
  longitude double precision check (longitude is null or (longitude >= -180 and longitude <= 180)),
  latitude double precision check (latitude is null or (latitude >= -90 and latitude <= 90)),
  coord_source text not null default 'interpolated'
    check (coord_source in ('interpolated', 'carried_last', 'missing_route')),

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

create or replace function public.haversine_meters(
  p_lon1 double precision,
  p_lat1 double precision,
  p_lon2 double precision,
  p_lat2 double precision
)
returns double precision
language sql
immutable
strict
as $$
  select
    2.0 * 6371000.0 * asin(
      least(
        1.0,
        sqrt(
          power(sin(radians((p_lat2 - p_lat1) / 2.0)), 2)
          + cos(radians(p_lat1))
          * cos(radians(p_lat2))
          * power(sin(radians((p_lon2 - p_lon1) / 2.0)), 2)
        )
      )
    );
$$;

create or replace function public.recompute_activity_sample_coordinates(p_activity_id uuid)
returns void
language plpgsql
as $$
begin
  with
    sample_base as (
      select
        s.activity_id,
        s.stroke_timestamp_ms,
        max(s.distance_m) over (
          partition by s.activity_id
          order by s.stroke_timestamp_ms
          rows between unbounded preceding and current row
        ) as effective_distance
      from public.activity_samples s
      where s.activity_id = p_activity_id
    ),
    route_points as (
      select
        a.id as activity_id,
        coord.ord::int as point_index,
        (coord.value->>0)::double precision as lon,
        (coord.value->>1)::double precision as lat
      from public.activities a
      cross join lateral jsonb_array_elements(a.route_geojson->'coordinates') with ordinality as coord(value, ord)
      where a.id = p_activity_id
        and a.route_geojson is not null
        and jsonb_typeof(a.route_geojson) = 'object'
        and a.route_geojson->>'type' = 'LineString'
        and jsonb_typeof(a.route_geojson->'coordinates') = 'array'
        and jsonb_typeof(coord.value) = 'array'
        and jsonb_array_length(coord.value) >= 2
        and (coord.value->>0) ~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$'
        and (coord.value->>1) ~ '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$'
    ),
    bounded_route_points as (
      select
        rp.activity_id,
        rp.point_index,
        rp.lon,
        rp.lat
      from route_points rp
      where rp.lon >= -180 and rp.lon <= 180
        and rp.lat >= -90 and rp.lat <= 90
    ),
    route_last as (
      select distinct on (rp.activity_id)
        rp.activity_id,
        rp.lon as last_lon,
        rp.lat as last_lat
      from bounded_route_points rp
      order by rp.activity_id, rp.point_index desc
    ),
    route_segments as (
      select
        rp.activity_id,
        rp.point_index,
        rp.lon as lon1,
        rp.lat as lat1,
        lead(rp.lon) over (partition by rp.activity_id order by rp.point_index) as lon2,
        lead(rp.lat) over (partition by rp.activity_id order by rp.point_index) as lat2
      from bounded_route_points rp
    ),
    route_segments_len as (
      select
        rs.activity_id,
        rs.point_index,
        rs.lon1,
        rs.lat1,
        rs.lon2,
        rs.lat2,
        public.haversine_meters(rs.lon1, rs.lat1, rs.lon2, rs.lat2) as seg_len_m
      from route_segments rs
      where rs.lon2 is not null
        and rs.lat2 is not null
    ),
    route_segments_cum as (
      select
        rsl.*,
        sum(rsl.seg_len_m) over (
          partition by rsl.activity_id
          order by rsl.point_index
          rows unbounded preceding
        ) as cum_end_m
      from route_segments_len rsl
    ),
    route_segments_bounds as (
      select
        rsc.activity_id,
        rsc.point_index,
        rsc.lon1,
        rsc.lat1,
        rsc.lon2,
        rsc.lat2,
        rsc.seg_len_m,
        (rsc.cum_end_m - rsc.seg_len_m) as cum_start_m,
        rsc.cum_end_m
      from route_segments_cum rsc
    ),
    route_totals as (
      select
        rl.activity_id,
        rl.last_lon,
        rl.last_lat,
        coalesce(max(rsb.cum_end_m), 0)::double precision as route_total_m
      from route_last rl
      left join route_segments_bounds rsb
        on rsb.activity_id = rl.activity_id
      group by rl.activity_id, rl.last_lon, rl.last_lat
    ),
    sample_coordinates as (
      select
        sb.activity_id,
        sb.stroke_timestamp_ms,
        case
          when rt.activity_id is null then null
          when rt.route_total_m <= 0 then rt.last_lon
          when sb.effective_distance >= rt.route_total_m then rt.last_lon
          when seg.activity_id is null then rt.last_lon
          when seg.seg_len_m <= 0 then seg.lon1
          else seg.lon1 + ((sb.effective_distance - seg.cum_start_m) / seg.seg_len_m) * (seg.lon2 - seg.lon1)
        end as longitude,
        case
          when rt.activity_id is null then null
          when rt.route_total_m <= 0 then rt.last_lat
          when sb.effective_distance >= rt.route_total_m then rt.last_lat
          when seg.activity_id is null then rt.last_lat
          when seg.seg_len_m <= 0 then seg.lat1
          else seg.lat1 + ((sb.effective_distance - seg.cum_start_m) / seg.seg_len_m) * (seg.lat2 - seg.lat1)
        end as latitude,
        case
          when rt.activity_id is null then 'missing_route'
          when rt.route_total_m <= 0 then 'carried_last'
          when sb.effective_distance >= rt.route_total_m then 'carried_last'
          when seg.activity_id is null then 'carried_last'
          else 'interpolated'
        end as coord_source
      from sample_base sb
      left join route_totals rt
        on rt.activity_id = sb.activity_id
      left join lateral (
        select rsb.*
        from route_segments_bounds rsb
        where rsb.activity_id = sb.activity_id
          and sb.effective_distance >= rsb.cum_start_m
          and sb.effective_distance < rsb.cum_end_m
        order by rsb.point_index
        limit 1
      ) seg on true
    )
  update public.activity_samples s
  set
    longitude = sc.longitude,
    latitude = sc.latitude,
    coord_source = sc.coord_source
  from sample_coordinates sc
  where s.activity_id = sc.activity_id
    and s.stroke_timestamp_ms = sc.stroke_timestamp_ms;
end;
$$;

create or replace function public.activity_samples_refresh_activity_metrics()
returns trigger
language plpgsql
as $$
declare
  v_activity_id uuid;
begin
  if tg_op = 'INSERT' then
    for v_activity_id in
      select distinct activity_id
      from new_rows
    loop
      perform public.recompute_activity_metrics_from_samples(v_activity_id);
      perform public.recompute_activity_sample_coordinates(v_activity_id);
    end loop;
    return null;
  end if;

  if tg_op = 'DELETE' then
    for v_activity_id in
      select distinct activity_id
      from old_rows
    loop
      perform public.recompute_activity_metrics_from_samples(v_activity_id);
      perform public.recompute_activity_sample_coordinates(v_activity_id);
    end loop;
    return null;
  end if;

  for v_activity_id in
    select distinct activity_id
    from (
      select activity_id from new_rows
      union
      select activity_id from old_rows
    ) changed
  loop
    perform public.recompute_activity_metrics_from_samples(v_activity_id);
    perform public.recompute_activity_sample_coordinates(v_activity_id);
  end loop;

  return null;
end;
$$;

drop trigger if exists trg_activity_samples_refresh_activity_metrics on public.activity_samples;
drop trigger if exists trg_activity_samples_refresh_activity_metrics_insert on public.activity_samples;
drop trigger if exists trg_activity_samples_refresh_activity_metrics_update on public.activity_samples;
drop trigger if exists trg_activity_samples_refresh_activity_metrics_delete on public.activity_samples;

create trigger trg_activity_samples_refresh_activity_metrics_insert
after insert on public.activity_samples
referencing new table as new_rows
for each statement execute function public.activity_samples_refresh_activity_metrics();

create trigger trg_activity_samples_refresh_activity_metrics_update
after update on public.activity_samples
referencing old table as old_rows new table as new_rows
for each statement execute function public.activity_samples_refresh_activity_metrics();

create trigger trg_activity_samples_refresh_activity_metrics_delete
after delete on public.activity_samples
referencing old table as old_rows
for each statement execute function public.activity_samples_refresh_activity_metrics();

create or replace function public.activities_refresh_sample_coordinates_on_route_change()
returns trigger
language plpgsql
as $$
begin
  perform public.recompute_activity_sample_coordinates(new.id);
  return new;
end;
$$;

drop trigger if exists trg_activities_refresh_sample_coordinates_on_route_change on public.activities;
create trigger trg_activities_refresh_sample_coordinates_on_route_change
after update of route_geojson on public.activities
for each row
when (old.route_geojson is distinct from new.route_geojson)
execute function public.activities_refresh_sample_coordinates_on_route_change();

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
