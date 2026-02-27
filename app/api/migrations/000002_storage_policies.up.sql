-- Enforce private buckets for app media.
update storage.buckets
set public = false
where id in ('avatars', 'workout-images');

-- Recreate policies idempotently.
drop policy if exists storage_select_own_objects on storage.objects;
drop policy if exists storage_insert_own_objects on storage.objects;
drop policy if exists storage_update_own_objects on storage.objects;
drop policy if exists storage_delete_own_objects on storage.objects;

-- Read only own objects in allowed buckets.
create policy storage_select_own_objects
on storage.objects
for select
to authenticated
using (
  bucket_id in ('avatars', 'workout-images')
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Insert only into own folder.
create policy storage_insert_own_objects
on storage.objects
for insert
to authenticated
with check (
  bucket_id in ('avatars', 'workout-images')
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Update only own objects and keep ownership prefix.
create policy storage_update_own_objects
on storage.objects
for update
to authenticated
using (
  bucket_id in ('avatars', 'workout-images')
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id in ('avatars', 'workout-images')
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Delete only own objects.
create policy storage_delete_own_objects
on storage.objects
for delete
to authenticated
using (
  bucket_id in ('avatars', 'workout-images')
  and (storage.foldername(name))[1] = auth.uid()::text
);
