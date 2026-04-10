create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'project_status') then
    create type public.project_status as enum (
      'planning',
      'active',
      'on_hold',
      'completed',
      'archived'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'project_member_role') then
    create type public.project_member_role as enum ('owner', 'admin', 'member', 'viewer');
  end if;

  if not exists (select 1 from pg_type where typname = 'task_status') then
    create type public.task_status as enum ('todo', 'in_progress', 'review', 'done');
  end if;

  if not exists (select 1 from pg_type where typname = 'task_priority') then
    create type public.task_priority as enum ('low', 'medium', 'high', 'urgent');
  end if;
end
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.set_audit_fields()
returns trigger
language plpgsql
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if tg_op = 'INSERT' then
    if new.created_at is null then
      new.created_at = timezone('utc', now());
    end if;
    if new.updated_at is null then
      new.updated_at = new.created_at;
    end if;
    if v_user_id is not null then
      if new.created_by is null then
        new.created_by = v_user_id;
      end if;
      if new.updated_by is null then
        new.updated_by = v_user_id;
      end if;
    end if;
  else
    new.updated_at = timezone('utc', now());
    if v_user_id is not null then
      new.updated_by = v_user_id;
    end if;
  end if;

  return new;
end;
$$;

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 200),
  description text not null default '',
  owner_id uuid not null references auth.users (id) on delete restrict,
  status public.project_status not null default 'planning',
  start_date date,
  target_end_date date,
  archived_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid not null references auth.users (id) on delete restrict,
  updated_by uuid not null references auth.users (id) on delete restrict,
  constraint projects_archived_status_check
    check ((archived_at is null and status <> 'archived') or (archived_at is not null and status = 'archived'))
);

create table if not exists public.project_members (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role public.project_member_role not null,
  joined_at timestamptz not null default timezone('utc', now()),
  added_by uuid not null references auth.users (id) on delete restrict,
  constraint project_members_unique_member unique (project_id, user_id)
);

create unique index if not exists project_members_unique_owner_per_project
  on public.project_members (project_id)
  where role = 'owner';

create table if not exists public.project_tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  parent_task_id uuid references public.project_tasks (id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 300),
  description text not null default '',
  status public.task_status not null default 'todo',
  priority public.task_priority not null default 'medium',
  assignee_id uuid references auth.users (id) on delete set null,
  reporter_id uuid not null references auth.users (id) on delete restrict,
  reviewer_id uuid references auth.users (id) on delete set null,
  assigned_by uuid references auth.users (id) on delete set null,
  start_date date,
  due_date timestamptz,
  completed_at timestamptz,
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes >= 0),
  actual_minutes integer check (actual_minutes is null or actual_minutes >= 0),
  progress_percent integer not null default 0 check (progress_percent between 0 and 100),
  order_index numeric(12,4),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid not null references auth.users (id) on delete restrict,
  updated_by uuid not null references auth.users (id) on delete restrict
);

create table if not exists public.project_task_labels (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  name text not null,
  color_hex text not null default '#4F62D8' check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid not null references auth.users (id) on delete restrict,
  updated_by uuid not null references auth.users (id) on delete restrict,
  constraint project_task_labels_unique_name_per_project unique (project_id, name)
);

create table if not exists public.project_task_label_map (
  task_id uuid not null references public.project_tasks (id) on delete cascade,
  label_id uuid not null references public.project_task_labels (id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  created_by uuid not null references auth.users (id) on delete restrict,
  primary key (task_id, label_id)
);

create table if not exists public.project_task_comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.project_tasks (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete restrict,
  comment_text text not null check (char_length(trim(comment_text)) > 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.project_task_attachments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  task_id uuid not null references public.project_tasks (id) on delete cascade,
  bucket_id text not null,
  storage_path text not null,
  file_name text not null,
  content_type text,
  file_size_bytes bigint,
  uploaded_by uuid not null references auth.users (id) on delete restrict,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid not null references auth.users (id) on delete restrict,
  updated_by uuid not null references auth.users (id) on delete restrict,
  constraint project_task_attachments_unique_storage_path unique (bucket_id, storage_path)
);

create table if not exists public.project_task_activity_logs (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  task_id uuid references public.project_tasks (id) on delete cascade,
  actor_id uuid not null references auth.users (id) on delete restrict,
  action_type text not null,
  old_value jsonb,
  new_value jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_projects_owner_id on public.projects (owner_id);
create index if not exists idx_projects_status_archived on public.projects (status, archived_at);
create index if not exists idx_project_members_project_id on public.project_members (project_id);
create index if not exists idx_project_members_user_id on public.project_members (user_id);
create index if not exists idx_project_tasks_project_status_order on public.project_tasks (project_id, status, order_index);
create index if not exists idx_project_tasks_project_assignee on public.project_tasks (project_id, assignee_id);
create index if not exists idx_project_tasks_project_due_date on public.project_tasks (project_id, due_date);
create index if not exists idx_project_tasks_parent_task_id on public.project_tasks (parent_task_id);
create index if not exists idx_project_task_comments_task_created on public.project_task_comments (task_id, created_at);
create index if not exists idx_project_task_attachments_task_created on public.project_task_attachments (task_id, created_at);
create index if not exists idx_project_task_activity_logs_project_created on public.project_task_activity_logs (project_id, created_at desc);
create index if not exists idx_project_task_activity_logs_task_created on public.project_task_activity_logs (task_id, created_at desc);

create or replace function public.is_project_member(
  p_project_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.project_members pm
    where pm.project_id = p_project_id
      and pm.user_id = coalesce(p_user_id, auth.uid())
  );
$$;

create or replace function public.project_member_has_role(
  p_project_id uuid,
  p_roles public.project_member_role[],
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.project_members pm
    where pm.project_id = p_project_id
      and pm.user_id = coalesce(p_user_id, auth.uid())
      and pm.role = any (p_roles)
  );
$$;

create or replace function public.ensure_single_project_owner()
returns trigger
language plpgsql
as $$
begin
  if new.role = 'owner' then
    update public.project_members
    set role = 'admin'
    where project_id = new.project_id
      and role = 'owner'
      and id <> coalesce(new.id, gen_random_uuid());
  end if;

  return new;
end;
$$;

create or replace function public.sync_project_owner_membership()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.project_members (project_id, user_id, role, joined_at, added_by)
  values (new.id, new.owner_id, 'owner', timezone('utc', now()), coalesce(auth.uid(), new.created_by))
  on conflict (project_id, user_id) do update
  set role = 'owner',
      added_by = excluded.added_by;

  return new;
end;
$$;

create or replace function public.handle_project_owner_transfer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.owner_id is distinct from old.owner_id then
    update public.project_members
    set role = 'admin'
    where project_id = new.id
      and user_id = old.owner_id
      and role = 'owner';

    insert into public.project_members (project_id, user_id, role, joined_at, added_by)
    values (new.id, new.owner_id, 'owner', timezone('utc', now()), coalesce(auth.uid(), new.updated_by))
    on conflict (project_id, user_id) do update
    set role = 'owner',
        added_by = excluded.added_by;
  end if;

  return new;
end;
$$;

create or replace function public.set_project_archive_fields()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'archived' and new.archived_at is null then
    new.archived_at = timezone('utc', now());
  elsif new.status <> 'archived' and new.archived_at is not null then
    new.archived_at = null;
  end if;

  return new;
end;
$$;

create or replace function public.enforce_project_update_permissions()
returns trigger
language plpgsql
as $$
begin
  if new.owner_id is distinct from old.owner_id
    and not public.project_member_has_role(old.id, array['owner']::public.project_member_role[], auth.uid()) then
    raise exception 'Only the project owner can transfer ownership';
  end if;

  if new.status = 'archived'
    and old.status is distinct from new.status
    and not public.project_member_has_role(old.id, array['owner']::public.project_member_role[], auth.uid()) then
    raise exception 'Only the project owner can archive the project';
  end if;

  return new;
end;
$$;

create or replace function public.validate_task_membership()
returns trigger
language plpgsql
as $$
declare
  v_project_id uuid;
begin
  v_project_id := new.project_id;

  if new.parent_task_id is not null and not exists (
    select 1 from public.project_tasks pt
    where pt.id = new.parent_task_id
      and pt.project_id = v_project_id
  ) then
    raise exception 'Parent task must belong to the same project';
  end if;

  if new.assignee_id is not null and not exists (
    select 1 from public.project_members pm
    where pm.project_id = v_project_id and pm.user_id = new.assignee_id
  ) then
    raise exception 'Assignee must be a project member';
  end if;

  if new.reviewer_id is not null and not exists (
    select 1 from public.project_members pm
    where pm.project_id = v_project_id and pm.user_id = new.reviewer_id
  ) then
    raise exception 'Reviewer must be a project member';
  end if;

  if not exists (
    select 1 from public.project_members pm
    where pm.project_id = v_project_id and pm.user_id = new.reporter_id
  ) then
    raise exception 'Reporter must be a project member';
  end if;

  return new;
end;
$$;

create or replace function public.set_task_defaults()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' and new.reporter_id is null then
    new.reporter_id = auth.uid();
  end if;

  if tg_op = 'INSERT' and new.order_index is null then
    select coalesce(max(t.order_index), 0) + 1
    into new.order_index
    from public.project_tasks t
    where t.project_id = new.project_id
      and t.status = new.status;
  end if;

  if tg_op = 'UPDATE' and new.assignee_id is distinct from old.assignee_id then
    new.assigned_by = auth.uid();
  end if;

  if new.status = 'done' and new.completed_at is null then
    new.completed_at = timezone('utc', now());
  elsif tg_op = 'UPDATE' and new.status <> 'done' and old.completed_at is not null then
    new.completed_at = null;
  end if;

  return new;
end;
$$;

create or replace function public.log_project_activity(
  p_project_id uuid,
  p_task_id uuid,
  p_action_type text,
  p_old_value jsonb default null,
  p_new_value jsonb default null,
  p_actor_id uuid default auth.uid()
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.project_task_activity_logs (
    project_id,
    task_id,
    actor_id,
    action_type,
    old_value,
    new_value
  )
  values (
    p_project_id,
    p_task_id,
    coalesce(p_actor_id, auth.uid()),
    p_action_type,
    p_old_value,
    p_new_value
  );
$$;

create or replace function public.handle_project_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_project_activity(new.id, null, 'project_created', null, to_jsonb(new));
    return new;
  end if;

  if tg_op = 'UPDATE' then
    perform public.log_project_activity(new.id, null, 'project_updated', to_jsonb(old), to_jsonb(new));
    return new;
  end if;

  return null;
end;
$$;

create or replace function public.handle_member_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_project_activity(
      new.project_id,
      null,
      'member_added',
      null,
      jsonb_build_object('user_id', new.user_id, 'role', new.role)
    );
    return new;
  end if;

  if tg_op = 'DELETE' then
    perform public.log_project_activity(
      old.project_id,
      null,
      'member_removed',
      jsonb_build_object('user_id', old.user_id, 'role', old.role),
      null
    );
    return old;
  end if;

  return null;
end;
$$;

create or replace function public.handle_task_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.log_project_activity(new.project_id, new.id, 'task_created', null, to_jsonb(new));
    return new;
  end if;

  if tg_op = 'UPDATE' then
    perform public.log_project_activity(new.project_id, new.id, 'task_updated', to_jsonb(old), to_jsonb(new));

    if new.assignee_id is distinct from old.assignee_id then
      perform public.log_project_activity(
        new.project_id,
        new.id,
        'task_assigned',
        jsonb_build_object('assignee_id', old.assignee_id),
        jsonb_build_object('assignee_id', new.assignee_id, 'assigned_by', new.assigned_by)
      );
    end if;

    if new.status is distinct from old.status then
      perform public.log_project_activity(
        new.project_id,
        new.id,
        'status_changed',
        jsonb_build_object('status', old.status),
        jsonb_build_object('status', new.status)
      );
    end if;

    if new.priority is distinct from old.priority then
      perform public.log_project_activity(
        new.project_id,
        new.id,
        'priority_changed',
        jsonb_build_object('priority', old.priority),
        jsonb_build_object('priority', new.priority)
      );
    end if;

    if new.due_date is distinct from old.due_date then
      perform public.log_project_activity(
        new.project_id,
        new.id,
        'due_date_changed',
        jsonb_build_object('due_date', old.due_date),
        jsonb_build_object('due_date', new.due_date)
      );
    end if;

    return new;
  end if;

  if tg_op = 'DELETE' then
    perform public.log_project_activity(old.project_id, old.id, 'task_deleted', to_jsonb(old), null);
    return old;
  end if;

  return null;
end;
$$;

create or replace function public.handle_comment_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_project_id uuid;
begin
  select t.project_id into v_project_id from public.project_tasks t where t.id = new.task_id;
  perform public.log_project_activity(
    v_project_id,
    new.task_id,
    'comment_added',
    null,
    jsonb_build_object('comment_id', new.id, 'user_id', new.user_id)
  );
  return new;
end;
$$;

create or replace function public.handle_attachment_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.log_project_activity(
    new.project_id,
    new.task_id,
    'attachment_uploaded',
    null,
    jsonb_build_object('attachment_id', new.id, 'file_name', new.file_name, 'storage_path', new.storage_path)
  );
  return new;
end;
$$;

create or replace view public.project_progress_summaries as
select
  p.id as project_id,
  count(t.id) as total_tasks,
  count(t.id) filter (where t.status = 'done') as done_tasks,
  count(t.id) filter (where t.due_date is not null and t.due_date < timezone('utc', now()) and t.status <> 'done') as overdue_tasks,
  count(t.id) filter (where t.status = 'in_progress') as in_progress_tasks,
  count(t.id) filter (where t.status = 'todo') as todo_tasks,
  count(t.id) filter (where t.status = 'review') as review_tasks,
  case
    when count(t.id) = 0 then 0
    else round((count(t.id) filter (where t.status = 'done')::numeric / count(t.id)::numeric) * 100, 2)
  end as completion_percent
from public.projects p
left join public.project_tasks t on t.project_id = p.id
group by p.id;

create or replace function public.get_project_summary(p_project_id uuid)
returns table (
  project_id uuid,
  total_tasks bigint,
  done_tasks bigint,
  overdue_tasks bigint,
  in_progress_tasks bigint,
  todo_tasks bigint,
  review_tasks bigint,
  completion_percent numeric
)
language sql
stable
as $$
  select *
  from public.project_progress_summaries s
  where s.project_id = p_project_id;
$$;

drop trigger if exists trg_projects_audit_fields on public.projects;
create trigger trg_projects_audit_fields
before insert or update on public.projects
for each row execute function public.set_audit_fields();

drop trigger if exists trg_projects_archive_fields on public.projects;
create trigger trg_projects_archive_fields
before insert or update on public.projects
for each row execute function public.set_project_archive_fields();

drop trigger if exists trg_projects_enforce_permissions on public.projects;
create trigger trg_projects_enforce_permissions
before update on public.projects
for each row execute function public.enforce_project_update_permissions();

drop trigger if exists trg_projects_owner_membership on public.projects;
create trigger trg_projects_owner_membership
after insert on public.projects
for each row execute function public.sync_project_owner_membership();

drop trigger if exists trg_projects_owner_transfer on public.projects;
create trigger trg_projects_owner_transfer
after update of owner_id on public.projects
for each row execute function public.handle_project_owner_transfer();

drop trigger if exists trg_projects_activity on public.projects;
create trigger trg_projects_activity
after insert or update on public.projects
for each row execute function public.handle_project_activity();

drop trigger if exists trg_project_members_single_owner on public.project_members;
create trigger trg_project_members_single_owner
before insert or update on public.project_members
for each row execute function public.ensure_single_project_owner();

drop trigger if exists trg_project_members_activity on public.project_members;
create trigger trg_project_members_activity
after insert or delete on public.project_members
for each row execute function public.handle_member_activity();

drop trigger if exists trg_project_tasks_audit_fields on public.project_tasks;
create trigger trg_project_tasks_audit_fields
before insert or update on public.project_tasks
for each row execute function public.set_audit_fields();

drop trigger if exists trg_project_tasks_defaults on public.project_tasks;
create trigger trg_project_tasks_defaults
before insert or update on public.project_tasks
for each row execute function public.set_task_defaults();

drop trigger if exists trg_project_tasks_membership_validation on public.project_tasks;
create trigger trg_project_tasks_membership_validation
before insert or update on public.project_tasks
for each row execute function public.validate_task_membership();

drop trigger if exists trg_project_tasks_activity on public.project_tasks;
create trigger trg_project_tasks_activity
after insert or update or delete on public.project_tasks
for each row execute function public.handle_task_activity();

drop trigger if exists trg_project_task_labels_audit_fields on public.project_task_labels;
create trigger trg_project_task_labels_audit_fields
before insert or update on public.project_task_labels
for each row execute function public.set_audit_fields();

drop trigger if exists trg_project_task_comments_updated_at on public.project_task_comments;
create trigger trg_project_task_comments_updated_at
before update on public.project_task_comments
for each row execute function public.set_updated_at();

drop trigger if exists trg_project_task_comments_activity on public.project_task_comments;
create trigger trg_project_task_comments_activity
after insert on public.project_task_comments
for each row execute function public.handle_comment_activity();

drop trigger if exists trg_project_task_attachments_audit_fields on public.project_task_attachments;
create trigger trg_project_task_attachments_audit_fields
before insert or update on public.project_task_attachments
for each row execute function public.set_audit_fields();

drop trigger if exists trg_project_task_attachments_activity on public.project_task_attachments;
create trigger trg_project_task_attachments_activity
after insert on public.project_task_attachments
for each row execute function public.handle_attachment_activity();
