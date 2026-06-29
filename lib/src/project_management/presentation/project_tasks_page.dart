import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../data/project_management_repository.dart';
import '../models/project_management_models.dart';

class ProjectTasksPage extends StatefulWidget {
  const ProjectTasksPage({super.key, required this.repository});

  final ProjectManagementRepository repository;

  @override
  State<ProjectTasksPage> createState() => _ProjectTasksPageState();
}

class _ProjectTasksPageState extends State<ProjectTasksPage> {
  late Future<({List<ProjectModel> projects, List<TaskModel> tasks})> _future;
  final _searchController = TextEditingController();
  TaskStatus? _filter;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    _future =
        Future.wait([
          widget.repository.getProjectsForCurrentUser(),
          widget.repository.getMyTasks(),
        ]).then(
          (values) => (
            projects: values[0] as List<ProjectModel>,
            tasks: values[1] as List<TaskModel>,
          ),
        );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _createTask(List<ProjectModel> projects) async {
    final activeProjects = projects
        .where(
          (project) =>
              project.status != ProjectStatus.completed &&
              project.status != ProjectStatus.archived,
        )
        .toList();
    if (activeProjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join or create an active project first.'),
        ),
      );
      return;
    }
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppPalette.background(context),
      builder: (_) => _CreateTaskSheet(
        repository: widget.repository,
        projects: activeProjects,
      ),
    );
    if (changed == true) await _refresh();
  }

  Future<void> _changeStatus(TaskModel task, TaskStatus status) async {
    try {
      await widget.repository.updateTask(
        taskId: task.id,
        status: status,
        progressPercent: status == TaskStatus.done
            ? 100
            : status == TaskStatus.inProgress
            ? 50
            : 0,
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child:
          FutureBuilder<({List<ProjectModel> projects, List<TaskModel> tasks})>(
            future: _future,
            builder: (context, snapshot) {
              final projects =
                  snapshot.data?.projects ?? const <ProjectModel>[];
              final projectNames = {
                for (final project in projects) project.id: project.name,
              };
              final query = _searchController.text.trim().toLowerCase();
              final tasks = (snapshot.data?.tasks ?? const <TaskModel>[]).where(
                (task) {
                  final statusMatches =
                      _filter == null || task.status == _filter;
                  final textMatches =
                      query.isEmpty ||
                      task.title.toLowerCase().contains(query) ||
                      (projectNames[task.projectId] ?? '')
                          .toLowerCase()
                          .contains(query);
                  return statusMatches && textMatches;
                },
              ).toList();

              return Scaffold(
                backgroundColor: Colors.transparent,
                floatingActionButton: FloatingActionButton(
                  onPressed: snapshot.hasData
                      ? () => _createTask(projects)
                      : null,
                  backgroundColor: const Color(0xFFFF3D7F),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.add_rounded, size: 30),
                ),
                body: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'My Tasks',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Created by you and assigned to you',
                                  style: TextStyle(
                                    color: AppPalette.mutedText(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF3D7F,
                              ).withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${snapshot.data?.tasks.length ?? 0}',
                              style: const TextStyle(
                                color: Color(0xFFFF3D7F),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search tasks or projects',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All',
                              selected: _filter == null,
                              onTap: () => setState(() => _filter = null),
                            ),
                            _FilterChip(
                              label: 'Planned',
                              selected: _filter == TaskStatus.todo,
                              onTap: () =>
                                  setState(() => _filter = TaskStatus.todo),
                            ),
                            _FilterChip(
                              label: 'Ongoing',
                              selected: _filter == TaskStatus.inProgress,
                              onTap: () => setState(
                                () => _filter = TaskStatus.inProgress,
                              ),
                            ),
                            _FilterChip(
                              label: 'Completed',
                              selected: _filter == TaskStatus.done,
                              onTap: () =>
                                  setState(() => _filter = TaskStatus.done),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (snapshot.hasError)
                        _MessageCard(
                          icon: Icons.cloud_off_rounded,
                          title: 'Could not load tasks',
                          subtitle: snapshot.error.toString(),
                        )
                      else if (tasks.isEmpty)
                        const _MessageCard(
                          icon: Icons.task_alt_rounded,
                          title: 'No tasks here',
                          subtitle: 'Create a task or try another filter.',
                        )
                      else
                        for (final task in tasks) ...[
                          _TaskCard(
                            task: task,
                            projectName:
                                projectNames[task.projectId] ?? 'Project',
                            onStatusChanged: (status) =>
                                _changeStatus(task, status),
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.projectName,
    required this.onStatusChanged,
  });
  final TaskModel task;
  final String projectName;
  final ValueChanged<TaskStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final overdue = task.isOverdue;
    final statusColor = switch (task.status) {
      TaskStatus.todo => const Color(0xFF718096),
      TaskStatus.inProgress => const Color(0xFFFF9417),
      TaskStatus.review => const Color(0xFF7557F7),
      TaskStatus.done => const Color(0xFF19B96B),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: overdue
              ? const Color(0xFFFF3D7F).withValues(alpha: .45)
              : AppPalette.border(context),
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.softShadow(context),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.checklist_rounded, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      projectName,
                      style: TextStyle(
                        color: AppPalette.mutedText(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<TaskStatus>(
                tooltip: 'Change status',
                initialValue: task.status,
                onSelected: onStatusChanged,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: TaskStatus.todo, child: Text('Planned')),
                  PopupMenuItem(
                    value: TaskStatus.inProgress,
                    child: Text('Ongoing'),
                  ),
                  PopupMenuItem(
                    value: TaskStatus.done,
                    child: Text('Completed'),
                  ),
                ],
                child: _StatusBadge(
                  label: _statusName(task.status),
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                overdue ? Icons.warning_amber_rounded : Icons.event_rounded,
                size: 17,
                color: overdue
                    ? const Color(0xFFFF3D7F)
                    : AppPalette.mutedText(context),
              ),
              const SizedBox(width: 7),
              Text(
                task.dueDate == null
                    ? 'No deadline'
                    : '${overdue ? 'Overdue · ' : 'Due '}${DateFormat('d MMM, y').format(task.dueDate!.toLocal())}',
                style: TextStyle(
                  color: overdue
                      ? const Color(0xFFFF3D7F)
                      : AppPalette.mutedText(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              _PriorityBadge(priority: task.priority),
            ],
          ),
        ],
      ),
    );
  }
}

String _statusName(TaskStatus status) => switch (status) {
  TaskStatus.todo => 'Planned',
  TaskStatus.inProgress => 'Ongoing',
  TaskStatus.review => 'Review',
  TaskStatus.done => 'Completed',
};

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final TaskPriority priority;
  @override
  Widget build(BuildContext context) {
    final color =
        priority == TaskPriority.urgent || priority == TaskPriority.high
        ? const Color(0xFFFF3D7F)
        : priority == TaskPriority.medium
        ? const Color(0xFFFF9417)
        : const Color(0xFF19B96B);
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          priority.name[0].toUpperCase() + priority.name.substring(1),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFFF3D7F).withValues(alpha: .15),
      labelStyle: TextStyle(
        color: selected
            ? const Color(0xFFFF3D7F)
            : AppPalette.mutedText(context),
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppPalette.surface(context),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        Icon(icon, size: 38, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppPalette.mutedText(context)),
        ),
      ],
    ),
  );
}

class _CreateTaskSheet extends StatefulWidget {
  const _CreateTaskSheet({required this.repository, required this.projects});
  final ProjectManagementRepository repository;
  final List<ProjectModel> projects;
  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late ProjectModel _project;
  List<ProjectMemberModel> _members = const [];
  String? _assigneeId;
  DateTime? _startDate;
  DateTime? _dueDate;
  TaskPriority _priority = TaskPriority.medium;
  bool _loadingMembers = false;
  bool _saving = false;

  bool get _ownsProject => _project.ownerId == widget.repository.currentUserId;

  @override
  void initState() {
    super.initState();
    _project = widget.projects.first;
    _assigneeId = widget.repository.currentUserId;
    _loadMembers();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (!_ownsProject) {
      setState(() {
        _members = const [];
        _assigneeId = widget.repository.currentUserId;
      });
      return;
    }
    setState(() => _loadingMembers = true);
    try {
      final members = await widget.repository.getProjectMembers(_project.id);
      if (mounted) {
        setState(() {
          _members = members;
          _assigneeId = members.any((m) => m.userId == _assigneeId)
              ? _assigneeId
              : widget.repository.currentUserId;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

  Future<void> _pickDate(bool start) async {
    final value = await showDatePicker(
      context: context,
      initialDate: start
          ? (_startDate ?? DateTime.now())
          : (_dueDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2100),
    );
    if (value == null) return;
    setState(() {
      if (start) {
        _startDate = value;
        if (_dueDate != null && _dueDate!.isBefore(value)) _dueDate = value;
      } else {
        _dueDate = value;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate != null &&
        _dueDate != null &&
        _dueDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be on or after the start date.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.createTask(
        projectId: _project.id,
        title: _title.text,
        description: _description.text,
        assigneeId: _assigneeId,
        startDate: _startDate,
        dueDate: _dueDate,
        priority: _priority,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Create Task',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ProjectModel>(
            initialValue: _project,
            decoration: const InputDecoration(labelText: 'Project'),
            items: widget.projects
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (p) {
              if (p == null) return;
              setState(() => _project = p);
              _loadMembers();
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Task title'),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Task title is required.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
          ),
          const SizedBox(height: 12),
          if (_ownsProject)
            DropdownButtonFormField<String>(
              initialValue: _assigneeId,
              decoration: InputDecoration(
                labelText: _loadingMembers ? 'Loading members…' : 'Assign to',
              ),
              items: _members
                  .map(
                    (m) => DropdownMenuItem(
                      value: m.userId,
                      child: Text(m.profile?.displayName ?? 'Member'),
                    ),
                  )
                  .toList(),
              onChanged: _loadingMembers
                  ? null
                  : (v) => setState(() => _assigneeId = v),
            )
          else
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Assigned to'),
              child: const Text('Me'),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TaskPriority>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: TaskPriority.values
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.name[0].toUpperCase() + p.name.substring(1)),
                  ),
                )
                .toList(),
            onChanged: (p) =>
                setState(() => _priority = p ?? TaskPriority.medium),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Start date',
                  value: _startDate,
                  onTap: () => _pickDate(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'End date',
                  value: _dueDate,
                  onTap: () => _pickDate(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_task_rounded),
            label: const Text('Create Task'),
          ),
        ],
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_rounded),
      ),
      child: Text(
        value == null ? 'Select' : DateFormat('d MMM, y').format(value!),
      ),
    ),
  );
}
