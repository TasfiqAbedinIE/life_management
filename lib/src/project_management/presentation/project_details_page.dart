import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../data/project_management_realtime.dart';
import '../data/project_management_repository.dart';
import '../models/project_management_models.dart';
import 'project_management_editors.dart';
import 'task_details_page.dart';

class ProjectDetailsPage extends StatefulWidget {
  const ProjectDetailsPage({
    super.key,
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final ProjectManagementRepository repository;

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _realtime = ProjectRealtimeSubscriptions();
  RealtimeChannel? _tasksChannel;
  RealtimeChannel? _activityChannel;

  late Future<ProjectModel> _projectFuture;
  late Future<List<ProjectMemberModel>> _membersFuture;
  late Future<List<TaskModel>> _tasksFuture;
  late Future<List<ActivityLogModel>> _activityFuture;
  TaskStatus? _filter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _reloadAll();
    _tasksChannel = _realtime.subscribeToTaskUpdates(
      projectId: widget.projectId,
      onEvent: (_) => _reloadTasksOnly(),
    );
    _activityChannel = _realtime.subscribeToActivityFeed(
      projectId: widget.projectId,
      onEvent: (_) => _reloadActivityOnly(),
    );
  }

  void _reloadAll() {
    _projectFuture = widget.repository.getProjectDetails(widget.projectId);
    _membersFuture = widget.repository.getProjectMembers(widget.projectId);
    _tasksFuture = widget.repository.getProjectTasks(projectId: widget.projectId);
    _activityFuture = widget.repository.getActivityFeed(widget.projectId);
  }

  void _reloadTasksOnly() {
    if (!mounted) return;
    setState(() => _tasksFuture = widget.repository.getProjectTasks(projectId: widget.projectId));
  }

  void _reloadActivityOnly() {
    if (!mounted) return;
    setState(() => _activityFuture = widget.repository.getActivityFeed(widget.projectId));
  }

  Future<void> _refresh() async {
    setState(_reloadAll);
    await Future.wait([_projectFuture, _membersFuture, _tasksFuture, _activityFuture]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_tasksChannel != null) {
      _realtime.disposeChannel(_tasksChannel!);
    }
    if (_activityChannel != null) {
      _realtime.disposeChannel(_activityChannel!);
    }
    super.dispose();
  }

  Future<void> _openTaskEditor({
    TaskModel? task,
    required List<ProjectMemberModel> members,
  }) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => TaskEditorSheet(
        projectId: widget.projectId,
        repository: widget.repository,
        members: members,
        task: task,
      ),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _openProjectEditor(ProjectModel project) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => ProjectEditorSheet(
        repository: widget.repository,
        project: project,
      ),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _quickStatusUpdate(TaskModel task, TaskStatus status) async {
    try {
      await widget.repository.updateTask(
        taskId: task.id,
        status: status,
        progressPercent: status == TaskStatus.done ? 100 : task.progressPercent,
      );
      if (!mounted) return;
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _deleteTask(TaskModel task) async {
    try {
      await widget.repository.deleteTask(task.id);
      if (!mounted) return;
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _archiveProject(ProjectModel project) async {
    try {
      await widget.repository.archiveProject(project.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _deleteProject(ProjectModel project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete project'),
        content: Text('Delete "${project.name}" and all related tasks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.repository.deleteProject(project.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4EF),
        title: const Text('Project Workspace'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<ProjectModel>(
          future: _projectFuture,
          builder: (context, projectSnapshot) {
            if (projectSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (projectSnapshot.hasError || !projectSnapshot.hasData) {
              return ListView(
                children: [Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(projectSnapshot.error.toString()),
                )],
              );
            }
            final project = projectSnapshot.data!;
            return FutureBuilder<List<ProjectMemberModel>>(
              future: _membersFuture,
              builder: (context, memberSnapshot) {
                final members = memberSnapshot.data ?? const <ProjectMemberModel>[];
                return _ProjectDetailsBody(
                  project: project,
                  members: members,
                  tasksFuture: _tasksFuture,
                  activityFuture: _activityFuture,
                  tabController: _tabController,
                  filter: _filter,
                  onFilterChanged: (value) => setState(() => _filter = value),
                  onEditProject: () => _openProjectEditor(project),
                  onArchiveProject: () => _archiveProject(project),
                  onDeleteProject: () => _deleteProject(project),
                  onEditTask: (task) => _openTaskEditor(task: task, members: members),
                  onCreateTask: () => _openTaskEditor(members: members),
                  onOpenTask: (task) async {
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => TaskDetailsPage(
                          task: task,
                          repository: widget.repository,
                          members: members,
                        ),
                      ),
                    );
                    if (changed == true) {
                      await _refresh();
                    }
                  },
                  onDeleteTask: _deleteTask,
                  onQuickStatusChange: _quickStatusUpdate,
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FutureBuilder<List<ProjectMemberModel>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          final members = snapshot.data ?? const <ProjectMemberModel>[];
          return FloatingActionButton.extended(
            backgroundColor: const Color(0xFFFF6A3D),
            foregroundColor: Colors.white,
            onPressed: () => _openTaskEditor(members: members),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Task'),
          );
        },
      ),
    );
  }
}

class _ProjectDetailsBody extends StatelessWidget {
  const _ProjectDetailsBody({
    required this.project,
    required this.members,
    required this.tasksFuture,
    required this.activityFuture,
    required this.tabController,
    required this.filter,
    required this.onFilterChanged,
    required this.onEditProject,
    required this.onArchiveProject,
    required this.onDeleteProject,
    required this.onEditTask,
    required this.onCreateTask,
    required this.onOpenTask,
    required this.onDeleteTask,
    required this.onQuickStatusChange,
  });

  final ProjectModel project;
  final List<ProjectMemberModel> members;
  final Future<List<TaskModel>> tasksFuture;
  final Future<List<ActivityLogModel>> activityFuture;
  final TabController tabController;
  final TaskStatus? filter;
  final ValueChanged<TaskStatus?> onFilterChanged;
  final VoidCallback onEditProject;
  final VoidCallback onArchiveProject;
  final VoidCallback onDeleteProject;
  final Future<void> Function(TaskModel task) onEditTask;
  final VoidCallback onCreateTask;
  final Future<void> Function(TaskModel task) onOpenTask;
  final Future<void> Function(TaskModel task) onDeleteTask;
  final Future<void> Function(TaskModel task, TaskStatus status) onQuickStatusChange;

  @override
  Widget build(BuildContext context) {
    final summary = project.summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.name,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEditProject();
                          break;
                        case 'archive':
                          onArchiveProject();
                          break;
                        case 'delete':
                          onDeleteProject();
                          break;
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit Project')),
                      PopupMenuItem(value: 'archive', child: Text('Archive Project')),
                      PopupMenuItem(value: 'delete', child: Text('Delete Project')),
                    ],
                  ),
                ],
              ),
              Text(
                project.description.isEmpty ? 'No description yet.' : project.description,
                style: TextStyle(color: AppPalette.mutedText(context)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoTag(label: formatStatusLabel(project.status), color: projectStatusColor(project.status), darkText: false),
                  _InfoTag(label: 'Start ${formatShortDate(project.startDate)}', color: const Color(0xFFF0F1F4), darkText: true),
                  _InfoTag(label: 'Due ${formatShortDate(project.targetEndDate)}', color: const Color(0xFFF0F1F4), darkText: true),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _MetricBox(value: '${summary?.inProgressTasks ?? 0}', label: 'In Progress', color: const Color(0xFF8E86FF))),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricBox(value: '${summary?.reviewTasks ?? 0}', label: 'Review', color: const Color(0xFFFF8D6B))),
                  const SizedBox(width: 10),
                  Expanded(child: _MetricBox(value: '${summary?.doneTasks ?? 0}', label: 'Done', color: const Color(0xFF24C49C))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [null, ...TaskStatus.values].map((status) {
              final selected = filter == status;
              final label = status == null ? 'All' : formatTaskStatusLabel(status);
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () => onFilterChanged(status),
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF171717) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(label, style: TextStyle(color: selected ? Colors.white : const Color(0xFF444444), fontWeight: FontWeight.w700)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: TabBar(
            controller: tabController,
            indicator: BoxDecoration(color: const Color(0xFF171717), borderRadius: BorderRadius.circular(999)),
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFF5B5B5B),
            dividerColor: Colors.transparent,
            tabs: const [Tab(text: 'List'), Tab(text: 'Board'), Tab(text: 'Calendar'), Tab(text: 'Members')],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: TabBarView(
            controller: tabController,
            children: [
              _TaskListTab(tasksFuture: tasksFuture, filter: filter, members: members, onEditTask: onEditTask, onOpenTask: onOpenTask, onDeleteTask: onDeleteTask, onQuickStatusChange: onQuickStatusChange),
              _BoardTab(tasksFuture: tasksFuture, filter: filter),
              _CalendarTab(tasksFuture: tasksFuture, filter: filter),
              _MembersTab(members: members, activityFuture: activityFuture, onCreateTask: onCreateTask),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _InfoTag extends StatelessWidget {
  const _InfoTag({required this.label, required this.color, required this.darkText});
  final String label;
  final Color color;
  final bool darkText;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: darkText ? const Color(0xFF171717) : Colors.white, fontWeight: FontWeight.w700)),
    );
  }
}

class _TaskListTab extends StatelessWidget {
  const _TaskListTab({
    required this.tasksFuture,
    required this.filter,
    required this.members,
    required this.onEditTask,
    required this.onOpenTask,
    required this.onDeleteTask,
    required this.onQuickStatusChange,
  });

  final Future<List<TaskModel>> tasksFuture;
  final TaskStatus? filter;
  final List<ProjectMemberModel> members;
  final Future<void> Function(TaskModel task) onEditTask;
  final Future<void> Function(TaskModel task) onOpenTask;
  final Future<void> Function(TaskModel task) onDeleteTask;
  final Future<void> Function(TaskModel task, TaskStatus status) onQuickStatusChange;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TaskModel>>(
      future: tasksFuture,
      builder: (context, snapshot) {
        final tasks = (snapshot.data ?? const <TaskModel>[])
            .where((task) => filter == null || task.status == filter)
            .toList();
        return ListView.separated(
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final task = tasks[index];
            final member = members.where((m) => m.userId == task.assigneeId).firstOrNull;
            return InkWell(
              onTap: () => onOpenTask(task),
              borderRadius: BorderRadius.circular(26),
              child: Ink(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: task.status == TaskStatus.done ? const Color(0xFF5DD56F) : Colors.white,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(task.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEditTask(task);
                            break;
                          case 'todo':
                            onQuickStatusChange(task, TaskStatus.todo);
                            break;
                          case 'in_progress':
                            onQuickStatusChange(task, TaskStatus.inProgress);
                            break;
                          case 'review':
                            onQuickStatusChange(task, TaskStatus.review);
                            break;
                          case 'done':
                            onQuickStatusChange(task, TaskStatus.done);
                            break;
                          case 'delete':
                            onDeleteTask(task);
                            break;
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit Task')),
                        PopupMenuItem(value: 'todo', child: Text('Move to To Do')),
                        PopupMenuItem(value: 'in_progress', child: Text('Move to In Progress')),
                        PopupMenuItem(value: 'review', child: Text('Move to Review')),
                        PopupMenuItem(value: 'done', child: Text('Move to Done')),
                        PopupMenuItem(value: 'delete', child: Text('Delete Task')),
                      ],
                    ),
                  ]),
                  Text(task.description.isEmpty ? 'No task description yet.' : task.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _InfoTag(label: task.priority.name.toUpperCase(), color: taskPriorityColor(task.priority), darkText: true),
                    _InfoTag(label: formatTaskStatusLabel(task.status), color: taskStatusColor(task.status), darkText: task.status != TaskStatus.done),
                    if (task.isOverdue) const _InfoTag(label: 'Overdue', color: Color(0xFFFF8D6B), darkText: false),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 15),
                    const SizedBox(width: 6),
                    Text(formatShortDate(task.dueDate)),
                    const Spacer(),
                    if (member != null)
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: const Color(0xFFEFE9DF),
                        child: Text(member.profile?.displayName.substring(0, 1).toUpperCase() ?? 'U'),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (task.progressPercent / 100).clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: Colors.black.withValues(alpha: 0.07),
                          color: const Color(0xFF24C49C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${task.progressPercent}%'),
                  ]),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _BoardTab extends StatelessWidget {
  const _BoardTab({required this.tasksFuture, required this.filter});
  final Future<List<TaskModel>> tasksFuture;
  final TaskStatus? filter;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TaskModel>>(
      future: tasksFuture,
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? const <TaskModel>[];
        final statuses = filter == null ? TaskStatus.values : [filter!];
        return ListView(
          scrollDirection: Axis.horizontal,
          children: statuses.map((status) {
            final columnTasks = tasks.where((task) => task.status == status).toList();
            return Container(
              width: 290,
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(formatTaskStatusLabel(status), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: columnTasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final task = columnTasks[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: status == TaskStatus.done ? const Color(0xFF5DD56F) : const Color(0xFFF7F4EF),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(task.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('Priority ${task.priority.name}'),
                          Text('Order ${task.orderIndex?.toStringAsFixed(0) ?? '-'}'),
                        ]),
                      );
                    },
                  ),
                ),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({required this.tasksFuture, required this.filter});
  final Future<List<TaskModel>> tasksFuture;
  final TaskStatus? filter;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TaskModel>>(
      future: tasksFuture,
      builder: (context, snapshot) {
        final tasks = (snapshot.data ?? const <TaskModel>[])
            .where((task) => task.startDate != null || task.dueDate != null)
            .where((task) => filter == null || task.status == filter)
            .toList();
        return ListView.separated(
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
              child: Row(children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: taskStatusColor(task.status).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(task.dueDate?.day.toString() ?? '--', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(task.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('Start ${formatShortDate(task.startDate)}'),
                    Text('Due ${formatShortDate(task.dueDate)}'),
                  ]),
                ),
                _InfoTag(label: formatTaskStatusLabel(task.status), color: taskStatusColor(task.status), darkText: task.status != TaskStatus.done),
              ]),
            );
          },
        );
      },
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.members,
    required this.activityFuture,
    required this.onCreateTask,
  });
  final List<ProjectMemberModel> members;
  final Future<List<ActivityLogModel>> activityFuture;
  final VoidCallback onCreateTask;
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: onCreateTask,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Task'),
          ),
        ),
        const SizedBox(height: 12),
        ...members.map((member) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFEFE9DF),
                  child: Text(member.profile?.displayName.substring(0, 1).toUpperCase() ?? 'U'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(member.profile?.displayName ?? member.userId, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(member.profile?.email ?? ''),
                  ]),
                ),
                Text(member.role.name),
              ]),
            )),
        const SizedBox(height: 6),
        const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        FutureBuilder<List<ActivityLogModel>>(
          future: activityFuture,
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <ActivityLogModel>[];
            return Column(
              children: items.take(8).map((item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFFFF6A3D)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.actionType.replaceAll('_', ' '))),
                  Text(formatShortDate(item.createdAt), style: TextStyle(color: AppPalette.mutedText(context))),
                ]),
              )).toList(),
            );
          },
        ),
      ],
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
