-- Persist per-stroke coordinates derived from distance over activity route.

alter table public.activity_samples
  add column if not exists longitude double precision
    check (longitude is null or (longitude >= -180 and longitude <= 180)),
  add column if not exists latitude double precision
    check (latitude is null or (latitude >= -90 and latitude <= 90)),
  add column if not exists coord_source text not null default 'interpolated'
    check (coord_source in ('interpolated', 'carried_last', 'missing_route'));

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

-- Backfill coordinates for existing rows.
do $$
declare
  v_activity_id uuid;
begin
  for v_activity_id in
    select distinct activity_id
    from public.activity_samples
  loop
    perform public.recompute_activity_sample_coordinates(v_activity_id);
  end loop;
end;
$$;
