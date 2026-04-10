insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'task-attachments',
  'task-attachments',
  false,
  52428800,
  array[
    'image/png',
    'image/jpeg',
    'image/webp',
    'application/pdf',
    'text/plain',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
on conflict (id) do nothing;

drop policy if exists "project_task_attachments_storage_select_member" on storage.objects;
create policy "project_task_attachments_storage_select_member" on storage.objects
for select to authenticated
using (
  bucket_id = 'task-attachments'
  and exists (
    select 1
    from public.project_task_attachments ta
    where ta.bucket_id = storage.objects.bucket_id
      and ta.storage_path = storage.objects.name
      and public.is_project_member(ta.project_id)
  )
);

drop policy if exists "project_task_attachments_storage_insert_working_member" on storage.objects;
create policy "project_task_attachments_storage_insert_working_member" on storage.objects
for insert to authenticated
with check (bucket_id = 'task-attachments' and split_part(name, '/', 1) = auth.uid()::text);

drop policy if exists "project_task_attachments_storage_update_owner" on storage.objects;
create policy "project_task_attachments_storage_update_owner" on storage.objects
for update to authenticated
using (bucket_id = 'task-attachments' and owner = auth.uid())
with check (bucket_id = 'task-attachments' and owner = auth.uid());

drop policy if exists "project_task_attachments_storage_delete_owner_admin" on storage.objects;
create policy "project_task_attachments_storage_delete_owner_admin" on storage.objects
for delete to authenticated
using (
  bucket_id = 'task-attachments'
  and (
    owner = auth.uid()
    or exists (
      select 1
      from public.project_task_attachments ta
      where ta.bucket_id = storage.objects.bucket_id
        and ta.storage_path = storage.objects.name
        and public.project_member_has_role(
          ta.project_id,
          array['owner','admin']::public.project_member_role[]
        )
    )
  )
);
