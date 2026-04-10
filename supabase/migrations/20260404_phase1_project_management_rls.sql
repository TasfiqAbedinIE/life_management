alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.project_tasks enable row level security;
alter table public.project_task_labels enable row level security;
alter table public.project_task_label_map enable row level security;
alter table public.project_task_comments enable row level security;
alter table public.project_task_attachments enable row level security;
alter table public.project_task_activity_logs enable row level security;

drop policy if exists "projects_select_member" on public.projects;
create policy "projects_select_member" on public.projects
for select using (owner_id = auth.uid() or public.is_project_member(id));

drop policy if exists "projects_insert_authenticated" on public.projects;
create policy "projects_insert_authenticated" on public.projects
for insert to authenticated
with check (auth.uid() is not null and owner_id = auth.uid() and created_by = auth.uid() and updated_by = auth.uid());

drop policy if exists "projects_update_owner_admin" on public.projects;
create policy "projects_update_owner_admin" on public.projects
for update to authenticated
using (public.project_member_has_role(id, array['owner','admin']::public.project_member_role[]))
with check (public.project_member_has_role(id, array['owner','admin']::public.project_member_role[]));

drop policy if exists "projects_delete_owner_only" on public.projects;
create policy "projects_delete_owner_only" on public.projects
for delete to authenticated
using (public.project_member_has_role(id, array['owner']::public.project_member_role[]));

drop policy if exists "project_members_select_member" on public.project_members;
create policy "project_members_select_member" on public.project_members
for select using (
  auth.uid() = user_id
  or exists (
    select 1 from public.projects p
    where p.id = project_id
      and p.owner_id = auth.uid()
  )
  or public.is_project_member(project_id)
);

drop policy if exists "project_members_insert_owner_admin" on public.project_members;
create policy "project_members_insert_owner_admin" on public.project_members
for insert to authenticated
with check (
  (
    public.project_member_has_role(project_id, array['owner','admin']::public.project_member_role[])
    or exists (
      select 1 from public.projects p
      where p.id = project_id
        and p.owner_id = auth.uid()
    )
  )
  and added_by = auth.uid()
  and exists (select 1 from public.profiles p where p.id = user_id)
  and (role <> 'owner' or public.project_member_has_role(project_id, array['owner']::public.project_member_role[]))
);

drop policy if exists "project_members_update_owner_admin" on public.project_members;
create policy "project_members_update_owner_admin" on public.project_members
for update to authenticated
using (public.project_member_has_role(project_id, array['owner','admin']::public.project_member_role[]))
with check (
  public.project_member_has_role(project_id, array['owner','admin']::public.project_member_role[])
  and (role <> 'owner' or public.project_member_has_role(project_id, array['owner']::public.project_member_role[]))
);

drop policy if exists "project_members_delete_owner_admin" on public.project_members;
create policy "project_members_delete_owner_admin" on public.project_members
for delete to authenticated
using (
  public.project_member_has_role(project_id, array['owner','admin']::public.project_member_role[])
  and (role <> 'owner' or public.project_member_has_role(project_id, array['owner']::public.project_member_role[]))
);

drop policy if exists "project_tasks_select_member" on public.project_tasks;
create policy "project_tasks_select_member" on public.project_tasks
for select using (public.is_project_member(project_id));

drop policy if exists "project_tasks_insert_working_member" on public.project_tasks;
create policy "project_tasks_insert_working_member" on public.project_tasks
for insert to authenticated
with check (
  public.project_member_has_role(project_id, array['owner','admin','member']::public.project_member_role[])
  and reporter_id = auth.uid()
  and created_by = auth.uid()
  and updated_by = auth.uid()
);

drop policy if exists "project_tasks_update_working_member" on public.project_tasks;
create policy "project_tasks_update_working_member" on public.project_tasks
for update to authenticated
using (public.project_member_has_role(project_id, array['owner','admin','member']::public.project_member_role[]))
with check (public.project_member_has_role(project_id, array['owner','admin','member']::public.project_member_role[]));

drop policy if exists "project_tasks_delete_working_member" on public.project_tasks;
create policy "project_tasks_delete_working_member" on public.project_tasks
for delete to authenticated
using (public.project_member_has_role(project_id, array['owner','admin','member']::public.project_member_role[]));

drop policy if exists "project_task_labels_select_member" on public.project_task_labels;
create policy "project_task_labels_select_member" on public.project_task_labels
for select using (public.is_project_member(project_id));

drop policy if exists "project_task_labels_mutate_working_member" on public.project_task_labels;
create policy "project_task_labels_mutate_working_member" on public.project_task_labels
for all to authenticated
using (public.project_member_has_role(project_id, array['owner','admin','member']::public.project_member_role[]))
with check (public.project_member_has_role(project_id, array['owner','admin','member']::public.project_member_role[]));

drop policy if exists "project_task_label_map_select_member" on public.project_task_label_map;
create policy "project_task_label_map_select_member" on public.project_task_label_map
for select using (
  exists (
    select 1 from public.project_tasks t
    where t.id = task_id and public.is_project_member(t.project_id)
  )
);

drop policy if exists "project_task_label_map_mutate_working_member" on public.project_task_label_map;
create policy "project_task_label_map_mutate_working_member" on public.project_task_label_map
for all to authenticated
using (
  exists (
    select 1 from public.project_tasks t
    where t.id = task_id
      and public.project_member_has_role(t.project_id, array['owner','admin','member']::public.project_member_role[])
  )
)
with check (
  exists (
    select 1 from public.project_tasks t
    where t.id = task_id
      and public.project_member_has_role(t.project_id, array['owner','admin','member']::public.project_member_role[])
  )
);

drop policy if exists "project_task_comments_select_member" on public.project_task_comments;
create policy "project_task_comments_select_member" on public.project_task_comments
for select using (
  exists (
    select 1 from public.project_tasks t
    where t.id = task_id and public.is_project_member(t.project_id)
  )
);

drop policy if exists "project_task_comments_insert_working_member" on public.project_task_comments;
create policy "project_task_comments_insert_working_member" on public.project_task_comments
for insert to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.project_tasks t
    where t.id = task_id
      and public.project_member_has_role(t.project_id, array['owner','admin','member']::public.project_member_role[])
  )
);

drop policy if exists "project_task_comments_update_author" on public.project_task_comments;
create policy "project_task_comments_update_author" on public.project_task_comments
for update to authenticated
using (
  user_id = auth.uid()
  and exists (
    select 1 from public.project_tasks t
    where t.id = task_id
      and public.project_member_has_role(t.project_id, array['owner','admin','member']::public.project_member_role[])
  )
)
with check (user_id = auth.uid());

drop policy if exists "project_task_comments_delete_author_or_admin" on public.project_task_comments;
create policy "project_task_comments_delete_author_or_admin" on public.project_task_comments
for delete to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1 from public.project_tasks t
    where t.id = task_id
      and public.project_member_has_role(t.project_id, array['owner','admin']::public.project_member_role[])
  )
);

drop policy if exists "project_task_attachments_select_member" on public.project_task_attachments;
create policy "project_task_attachments_select_member" on public.project_task_attachments
for select using (public.is_project_member(project_id));

drop policy if exists "project_task_attachments_insert_working_member" on public.project_task_attachments;
create policy "project_task_attachments_insert_working_member" on public.project_task_attachments
for insert to authenticated
with check (
  uploaded_by = auth.uid()
  and created_by = auth.uid()
  and updated_by = auth.uid()
  and public.project_member_has_role(project_id, array['owner','admin','member']::public.project_member_role[])
);

drop policy if exists "project_task_attachments_delete_working_member" on public.project_task_attachments;
create policy "project_task_attachments_delete_working_member" on public.project_task_attachments
for delete to authenticated
using (public.project_member_has_role(project_id, array['owner','admin','member']::public.project_member_role[]));

drop policy if exists "project_task_activity_logs_select_member" on public.project_task_activity_logs;
create policy "project_task_activity_logs_select_member" on public.project_task_activity_logs
for select using (public.is_project_member(project_id));

drop policy if exists "project_task_activity_logs_block_mutation" on public.project_task_activity_logs;
create policy "project_task_activity_logs_block_mutation" on public.project_task_activity_logs
for all to authenticated
using (false)
with check (false);
