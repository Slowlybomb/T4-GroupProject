-- Remove auth.users -> profiles auto-create trigger.

drop trigger if exists trg_auth_users_create_profile on auth.users;
drop function if exists public.create_profile_for_new_auth_user();
