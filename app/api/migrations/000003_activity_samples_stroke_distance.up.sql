-- Store raw stroke events (timestamp + distance) and derive activity aggregates.

-- Legacy rows were keyed by t_offset_ms; rename to reflect raw stroke timestamps.
alter table public.activity_samples
  rename column t_offset_ms to stroke_timestamp_ms;

alter table public.activity_samples
  alter column stroke_timestamp_ms type bigint using stroke_timestamp_ms::bigint;

-- Keep existing rows valid during migration (legacy rows get distance 0 by default).
alter table public.activity_samples
  add column if not exists distance_m double precision not null default 0
  check (distance_m >= 0);

alter table public.activity_samples
  alter column distance_m drop default;

-- Remove obsolete per-sample metrics that are now derived from stroke events.
alter table public.activity_samples
  drop column if exists pace_500m_seconds,
  drop column if exists speed_mps,
  drop column if exists stroke_spm,
  drop column if exists accuracy_m;

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
