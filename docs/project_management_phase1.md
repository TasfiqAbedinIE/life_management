# Project Management Phase 1

## Assumptions

- The app already has a `public.profiles` table linked to `auth.users`, so this module reuses it for member search and member display.
- Attachments need both storage files and relational metadata, so `project_task_attachments` is included for Phase 1.
- Ownership transfer is handled by updating `projects.owner_id`; triggers keep `project_members` consistent.

## 1. Architecture overview

- `supabase/migrations/20260404_phase1_project_management.sql`: schema, constraints, indexes, helper functions, activity triggers, and project summary view/RPC.
- `supabase/migrations/20260404_phase1_project_management_rls.sql`: table-level RLS policies for all project-domain tables.
- `supabase/storage/20260404_task_attachments_storage.sql`: private storage bucket and attachment object policies.
- `lib/src/project_management/models/project_management_models.dart`: typed entities, DTOs, filters, and mappers.
- `lib/src/project_management/data/project_management_repository.dart`: Supabase operations for projects, members, tasks, board/list/calendar responses, comments, attachments, feed, and summary.
- `lib/src/project_management/data/project_management_realtime.dart`: Realtime subscription helpers for comments, tasks, board refresh, and activity feed refresh.
- `lib/src/project_management/presentation/*.dart`: Phase 1 UI shell for Project List, Project Details, Task Details, Members, Board, and Calendar.

## 2. Final database schema design

- `projects`: project metadata, lifecycle fields, ownership, and audit columns.
- `project_members`: membership rows with one unique owner per project.
- `project_tasks`: project-scoped tasks with assignee, reporter, reviewer, hierarchy, dates, and sortable `order_index`.
- `project_task_labels` and `project_task_label_map`: reusable project labels.
- `project_task_comments`: chronological task discussion with mention-ready JSON metadata.
- `project_task_attachments`: metadata for files stored in Supabase Storage.
- `project_task_activity_logs`: project/task activity stream.
- `project_progress_summaries` view plus `get_project_summary(uuid)`: efficient stats for dashboard cards and filters.

## 5. Storage bucket strategy and policy examples

- Bucket: `task-attachments`
- Visibility: private
- Path strategy: `{auth.uid()}/{project_id}/{task_id}/{timestamp}_{filename}`
- File metadata is persisted in `public.project_task_attachments`
- Access model:
  - owner/admin/member can upload attachment files and metadata
  - project members can read attachment metadata and files
  - owner/admin can remove files created by anyone in the project

See:

- `supabase/storage/20260404_task_attachments_storage.sql`
- `supabase/migrations/20260404_phase1_project_management.sql`
- `supabase/migrations/20260404_phase1_project_management_rls.sql`

## 6. Backend/service layer code

- Repository: `lib/src/project_management/data/project_management_repository.dart`
- Realtime: `lib/src/project_management/data/project_management_realtime.dart`
- Models and mappers: `lib/src/project_management/models/project_management_models.dart`

Implemented repository methods:

- `createProject(...)`
- `updateProject(...)`
- `archiveProject(...)`
- `getProjectsForCurrentUser(...)`
- `getProjectDetails(...)`
- `searchRegisteredUsersForProjectMemberAdd(...)`
- `addProjectMember(...)`
- `removeProjectMember(...)`
- `getProjectMembers(...)`
- `createTask(...)`
- `updateTask(...)`
- `deleteTask(...)`
- `assignTask(...)`
- `moveTaskStatus(...)`
- `reorderTask(...)`
- `getProjectTasks(...)`
- `getBoardData(...)`
- `getCalendarTasks(...)`
- `addComment(...)`
- `getTaskComments(...)`
- `uploadTaskAttachment(...)`
- `getTaskAttachments(...)`
- `getActivityFeed(...)`
- `getProjectSummary(...)`

## 7. Realtime subscription examples

Realtime helper file:

- `lib/src/project_management/data/project_management_realtime.dart`

Subscriptions included:

- `subscribeToTaskComments(taskId: ..., onEvent: ...)`
- `subscribeToTaskUpdates(projectId: ..., onEvent: ...)`
- `subscribeToBoardRefresh(projectId: ..., onEvent: ...)`
- `subscribeToActivityFeed(projectId: ..., onEvent: ...)`

Typical usage pattern:

```dart
final realtime = ProjectRealtimeSubscriptions();
final channel = realtime.subscribeToTaskComments(
  taskId: taskId,
  onEvent: (_) {
    setState(() {
      _commentsFuture = repository.getTaskComments(taskId);
    });
  },
);
```

## 8. Example queries

### Project list

```sql
select
  p.*,
  s.total_tasks,
  s.done_tasks,
  s.overdue_tasks,
  s.completion_percent
from public.projects p
left join public.project_progress_summaries s on s.project_id = p.id
where public.is_project_member(p.id)
  and p.archived_at is null
order by p.updated_at desc;
```

### Board data

```sql
select
  id,
  project_id,
  title,
  status,
  priority,
  assignee_id,
  due_date,
  order_index
from public.project_tasks
where project_id = :project_id
order by status asc, order_index asc nulls last, updated_at desc;
```

### Overdue tasks

```sql
select *
from public.project_tasks
where project_id = :project_id
  and due_date < timezone('utc', now())
  and status <> 'done'
order by due_date asc;
```

### Project progress summary

```sql
select * from public.get_project_summary(:project_id);
```

## 10. Future-ready notes for phase 2 integration

- Notifications can subscribe directly to `project_task_activity_logs` and `project_task_comments`.
- Timeline/Gantt can reuse `start_date`, `due_date`, `target_end_date`, and `parent_task_id`.
- Automation rules can trigger off `task_status`, `due_date`, and the activity stream.
- AI summaries can read projects, tasks, comments, attachments, and activity logs without a schema redesign.

## 9. Suggested UI screen structure

- Project List
  - active projects first
  - summary pills for tasks, done, overdue
  - quick create project CTA
- Project Details
  - hero summary header
  - tabs for List, Board, Calendar, Members
  - floating action button for new task
- Task Details
  - task overview card
  - attachments section
  - live comments section
- Members
  - current member list
  - project role picker and user search
- Board
  - task columns grouped by status
  - order shown via `order_index`
- Calendar
  - task cards filtered to start/due date aware items

UI entry point files:

- `lib/src/project_management/presentation/project_management_page.dart`
- `lib/src/project_management/presentation/project_details_page.dart`
- `lib/src/project_management/presentation/task_details_page.dart`
