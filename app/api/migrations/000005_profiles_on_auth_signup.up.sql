-- Auto-create profile rows when Supabase auth users sign up.

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
  -- Keep username deterministic and unique per user id.
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

-- Backfill existing auth users that do not have a profile row yet.
insert into public.profiles (id, username, display_name)
select
  u.id,
  'user_' || replace(u.id::text, '-', ''),
  nullif(trim(coalesce(u.raw_user_meta_data->>'full_name', '')), '')
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
on conflict (id) do nothing;
