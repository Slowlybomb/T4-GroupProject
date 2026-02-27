-- Roll back initial schema objects created in 000001_initial_schema.up.sql.

-- Policies/triggers/functions first, then dependent tables.
drop policy if exists activities_delete_own on public.activities;
drop policy if exists activities_update_own on public.activities;
drop policy if exists activities_insert_own on public.activities;
drop policy if exists activities_select_visibility on public.activities;

drop trigger if exists trg_teams_add_owner_member on public.teams;
drop function if exists public.add_team_owner_member();

drop table if exists public.activity_comments;
drop table if exists public.activity_likes;
drop table if exists public.follows;
drop table if exists public.activity_samples;
drop table if exists public.activities;
drop table if exists public.team_members;
drop table if exists public.teams;
drop table if exists public.profiles;

-- Extensions are left in place intentionally because they are often shared.
