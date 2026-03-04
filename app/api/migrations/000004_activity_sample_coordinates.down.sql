-- Remove per-stroke coordinate persistence and restore 000003 trigger behavior.

drop trigger if exists trg_activities_refresh_sample_coordinates_on_route_change on public.activities;
drop function if exists public.activities_refresh_sample_coordinates_on_route_change();

drop trigger if exists trg_activity_samples_refresh_activity_metrics_insert on public.activity_samples;
drop trigger if exists trg_activity_samples_refresh_activity_metrics_update on public.activity_samples;
drop trigger if exists trg_activity_samples_refresh_activity_metrics_delete on public.activity_samples;
drop trigger if exists trg_activity_samples_refresh_activity_metrics on public.activity_samples;

drop function if exists public.recompute_activity_sample_coordinates(uuid);
drop function if exists public.haversine_meters(double precision, double precision, double precision, double precision);

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

create trigger trg_activity_samples_refresh_activity_metrics
after insert or update or delete on public.activity_samples
for each row execute function public.activity_samples_refresh_activity_metrics();

alter table public.activity_samples
  drop column if exists longitude,
  drop column if exists latitude,
  drop column if exists coord_source;
