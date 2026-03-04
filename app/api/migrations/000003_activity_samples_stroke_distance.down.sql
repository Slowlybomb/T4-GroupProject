-- Roll back raw stroke-event schema changes for activity_samples.

drop trigger if exists trg_activity_samples_refresh_activity_metrics on public.activity_samples;
drop function if exists public.activity_samples_refresh_activity_metrics();
drop function if exists public.recompute_activity_metrics_from_samples(uuid);

alter table public.activity_samples
  add column if not exists pace_500m_seconds int check (pace_500m_seconds is null or pace_500m_seconds >= 0),
  add column if not exists speed_mps real check (speed_mps is null or speed_mps >= 0),
  add column if not exists stroke_spm smallint check (stroke_spm is null or stroke_spm >= 0),
  add column if not exists accuracy_m real check (accuracy_m is null or accuracy_m >= 0);

alter table public.activity_samples
  drop column if exists distance_m;

alter table public.activity_samples
  alter column stroke_timestamp_ms type integer using stroke_timestamp_ms::integer;

alter table public.activity_samples
  rename column stroke_timestamp_ms to t_offset_ms;
