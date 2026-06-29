import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../data/project_management_repository.dart';
import '../models/project_management_models.dart';
import 'project_management_editors.dart';
import 'task_details_page.dart';

class ProjectOverviewPage extends StatefulWidget {
  const ProjectOverviewPage({
    super.key,
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final ProjectManagementRepository repository;

  @override
  State<ProjectOverviewPage> createState() => _ProjectOverviewPageState();
}

class _ProjectOverviewPageState extends State<ProjectOverviewPage> {
  late Future<
    ({
      ProjectModel project,
      List<ProjectMemberModel> members,
      List<TaskModel> tasks,
    })
  >
  _future;
  TaskStatus? _filter;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future =
        Future.wait([
          widget.repository.getProjectDetails(widget.projectId),
          widget.repository.getProjectMembers(widget.projectId),
          widget.repository.getProjectTasks(projectId: widget.projectId),
        ]).then(
          (values) => (
            project: values[0] as ProjectModel,
            members: values[1] as List<ProjectMemberModel>,
            tasks: values[2] as List<TaskModel>,
          ),
        );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _createTask(List<ProjectMemberModel> members) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppPalette.background(context),
      builder: (_) => TaskEditorSheet(
        projectId: widget.projectId,
        repository: widget.repository,
        members: members,
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

  Future<void> _openTask(
    TaskModel task,
    List<ProjectMemberModel> members,
  ) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskDetailsPage(
          task: task,
          repository: widget.repository,
          members: members,
        ),
      ),
    );
    if (changed == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      body: SafeArea(
        child:
            FutureBuilder<
              ({
                ProjectModel project,
                List<ProjectMemberModel> members,
                List<TaskModel> tasks,
              })
            >(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return _LoadError(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }

                final data = snapshot.data!;
                final tasks = data.tasks
                    .where((task) => _filter == null || task.status == _filter)
                    .toList();
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
                    children: [
                      _PageHeader(project: data.project),
                      const SizedBox(height: 20),
                      _ProjectHero(project: data.project, tasks: data.tasks),
                      const SizedBox(height: 18),
                      _MembersSection(members: data.members),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Project Tasks',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            '${data.tasks.length} tasks',
                            style: TextStyle(
                              color: AppPalette.mutedText(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _StatusFilter(
                              label: 'All',
                              selected: _filter == null,
                              onTap: () => setState(() => _filter = null),
                            ),
                            _StatusFilter(
                              label: 'Planned',
                              selected: _filter == TaskStatus.todo,
                              onTap: () =>
                                  setState(() => _filter = TaskStatus.todo),
                            ),
                            _StatusFilter(
                              label: 'Ongoing',
                              selected: _filter == TaskStatus.inProgress,
                              onTap: () => setState(
                                () => _filter = TaskStatus.inProgress,
                              ),
                            ),
                            _StatusFilter(
                              label: 'Completed',
                              selected: _filter == TaskStatus.done,
                              onTap: () =>
                                  setState(() => _filter = TaskStatus.done),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (tasks.isEmpty)
                        const _EmptyTasks()
                      else
                        for (final task in tasks) ...[
                          _ProjectTaskCard(
                            task: task,
                            assignee: _assignee(data.members, task.assigneeId),
                            onTap: () => _openTask(task, data.members),
                            onStatusChanged: (status) =>
                                _changeStatus(task, status),
                          ),
                          const SizedBox(height: 11),
                        ],
                    ],
                  ),
                );
              },
            ),
      ),
      floatingActionButton:
          FutureBuilder<
            ({
              ProjectModel project,
              List<ProjectMemberModel> members,
              List<TaskModel> tasks,
            })
          >(
            future: _future,
            builder: (context, snapshot) => FloatingActionButton.extended(
              onPressed: snapshot.hasData
                  ? () => _createTask(snapshot.data!.members)
                  : null,
              backgroundColor: const Color(0xFFFF3D7F),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('New Task'),
            ),
          ),
    );
  }

  ProjectMemberModel? _assignee(
    List<ProjectMemberModel> members,
    String? userId,
  ) {
    for (final member in members) {
      if (member.userId == userId) return member;
    }
    return null;
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.project});
  final ProjectModel project;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton.filledTonal(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          'Project Details',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: projectStatusColor(project.status).withValues(alpha: .13),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          formatStatusLabel(project.status),
          style: TextStyle(
            color: projectStatusColor(project.status),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

class _ProjectHero extends StatelessWidget {
  const _ProjectHero({required this.project, required this.tasks});
  final ProjectModel project;
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    final completed = tasks
        .where((task) => task.status == TaskStatus.done)
        .length;
    final ongoing = tasks
        .where((task) => task.status == TaskStatus.inProgress)
        .length;
    final percent = tasks.isEmpty
        ? 0
        : ((completed / tasks.length) * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppPalette.heroGradient(context)),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF263A8B).withValues(alpha: .25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            project.description.isEmpty
                ? 'No description added yet.'
                : project.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .76),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(value: '${tasks.length}', label: 'Tasks'),
              ),
              Expanded(
                child: _HeroMetric(value: '$ongoing', label: 'Ongoing'),
              ),
              Expanded(
                child: _HeroMetric(value: '$completed', label: 'Completed'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: .16),
                    color: const Color(0xFFFF4F91),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _DatePill(label: 'Start', value: project.startDate),
              _DatePill(label: 'Deadline', value: project.targetEndDate),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .66),
          fontSize: 11,
        ),
      ),
    ],
  );
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label, required this.value});
  final String label;
  final DateTime? value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 15),
        const SizedBox(width: 6),
        Text(
          '$label ${value == null ? '—' : DateFormat('d MMM, y').format(value!.toLocal())}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _MembersSection extends StatelessWidget {
  const _MembersSection({required this.members});
  final List<ProjectMemberModel> members;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: AppPalette.surface(context),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppPalette.border(context)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Project Members',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${members.length}',
              style: const TextStyle(
                color: Color(0xFF7557F7),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (members.isEmpty)
          Text(
            'No members yet',
            style: TextStyle(color: AppPalette.mutedText(context)),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final member in members)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _MemberItem(member: member),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _MemberItem extends StatelessWidget {
  const _MemberItem({required this.member});
  final ProjectMemberModel member;
  @override
  Widget build(BuildContext context) {
    final name = member.profile?.memberName ?? 'Member';
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF7557F7).withValues(alpha: .16),
            foregroundColor: const Color(0xFF7557F7),
            child: Text(
              name.isEmpty ? 'U' : name[0].toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
          Text(
            member.role.name,
            style: TextStyle(fontSize: 9, color: AppPalette.mutedText(context)),
          ),
        ],
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
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
      selectedColor: const Color(0xFFFF3D7F).withValues(alpha: .14),
      labelStyle: TextStyle(
        color: selected
            ? const Color(0xFFFF3D7F)
            : AppPalette.mutedText(context),
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ProjectTaskCard extends StatelessWidget {
  const _ProjectTaskCard({
    required this.task,
    required this.assignee,
    required this.onTap,
    required this.onStatusChanged,
  });
  final TaskModel task;
  final ProjectMemberModel? assignee;
  final VoidCallback onTap;
  final ValueChanged<TaskStatus> onStatusChanged;
  @override
  Widget build(BuildContext context) {
    final color = taskStatusColor(task.status);
    return Material(
      color: AppPalette.surface(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: task.isOverdue
                  ? const Color(0xFFFF3D7F).withValues(alpha: .45)
                  : AppPalette.border(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 41,
                    height: 41,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.task_alt_rounded, color: color),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  PopupMenuButton<TaskStatus>(
                    tooltip: 'Change status',
                    initialValue: task.status,
                    onSelected: onStatusChanged,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: TaskStatus.todo,
                        child: Text('Planned'),
                      ),
                      PopupMenuItem(
                        value: TaskStatus.inProgress,
                        child: Text('Ongoing'),
                      ),
                      PopupMenuItem(
                        value: TaskStatus.done,
                        child: Text('Completed'),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        _taskStatus(task.status),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Icon(
                    task.isOverdue
                        ? Icons.warning_amber_rounded
                        : Icons.event_rounded,
                    size: 16,
                    color: task.isOverdue
                        ? const Color(0xFFFF3D7F)
                        : AppPalette.mutedText(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    task.dueDate == null
                        ? 'No deadline'
                        : '${task.isOverdue ? 'Overdue · ' : ''}${DateFormat('d MMM, y').format(task.dueDate!.toLocal())}',
                    style: TextStyle(
                      color: task.isOverdue
                          ? const Color(0xFFFF3D7F)
                          : AppPalette.mutedText(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (assignee != null)
                    Text(
                      assignee!.profile?.memberName ?? 'Member',
                      style: TextStyle(
                        color: AppPalette.mutedText(context),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _taskStatus(TaskStatus status) => switch (status) {
  TaskStatus.todo => 'Planned',
  TaskStatus.inProgress => 'Ongoing',
  TaskStatus.review => 'Review',
  TaskStatus.done => 'Completed',
};

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppPalette.surface(context),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        const Icon(Icons.add_task_rounded, size: 38, color: Color(0xFF7557F7)),
        const SizedBox(height: 10),
        const Text(
          'No tasks in this view',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          'Use New Task to add the first one.',
          style: TextStyle(color: AppPalette.mutedText(context)),
        ),
      ],
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
