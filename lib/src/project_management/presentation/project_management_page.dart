import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/project_management_repository.dart';
import '../models/project_management_models.dart';
import 'project_management_editors.dart';
import 'project_overview_page.dart';
import 'project_tasks_page.dart';

class ProjectManagementPage extends StatefulWidget {
  const ProjectManagementPage({super.key});

  @override
  State<ProjectManagementPage> createState() => _ProjectManagementPageState();
}

class _ProjectManagementPageState extends State<ProjectManagementPage> {
  final _repository = ProjectManagementRepository();

  late Future<List<ProjectModel>> _projectsFuture;
  int _selectedDestination = 0;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _repository.getProjectsForCurrentUser();
  }

  Future<void> _refresh() async {
    setState(() {
      _projectsFuture = _repository.getProjectsForCurrentUser();
    });
    await _projectsFuture;
  }

  Future<void> _openProjectEditor([ProjectModel? project]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) =>
          ProjectEditorSheet(repository: _repository, project: project),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _openProject(ProjectModel project) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ProjectOverviewPage(projectId: project.id, repository: _repository),
      ),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  // Kept ready for the Team destination when that screen is designed.
  // ignore: unused_element
  Future<void> _openMemberEditor(ProjectModel project) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) =>
          _AddProjectMemberSheet(project: project, repository: _repository),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _archiveProject(ProjectModel project) async {
    try {
      await _repository.archiveProject(project.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${project.name}" archived.')));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _deleteProject(ProjectModel project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete project'),
        content: Text(
          'Delete "${project.name}" and its related project data? This cannot be undone.',
        ),
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
      await _repository.deleteProject(project.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${project.name}" deleted.')));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<Map<String, List<ProjectMemberModel>>> _loadMembersForProjects(
    List<ProjectModel> projects,
  ) async {
    final entries = await Future.wait(
      projects.map((project) async {
        final members = await _repository.getProjectMembers(project.id);
        return MapEntry(project.id, members);
      }),
    );
    return Map<String, List<ProjectMemberModel>>.fromEntries(entries);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = AppPalette.background(context);

    return Scaffold(
      backgroundColor: background,
      floatingActionButton: _selectedDestination == 0
          ? FloatingActionButton(
              onPressed: () => _openProjectEditor(),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 0,
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      bottomNavigationBar: _ProjectBottomNavigation(
        selectedIndex: _selectedDestination,
        onSelected: (index) => setState(() => _selectedDestination = index),
      ),
      body: _selectedDestination == 0
          ? SafeArea(
              child: FutureBuilder<List<ProjectModel>>(
                future: _projectsFuture,
                builder: (context, snapshot) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                      children: [
                        _ProjectsHeader(
                          projectCount: snapshot.data?.length ?? 0,
                          onBack: () => Navigator.of(context).maybePop(),
                          onNotifications: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Notifications are reserved for the next phase.',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const _ProjectsLoadingState()
                        else if (snapshot.hasError)
                          _ProjectsErrorState(
                            message: snapshot.error.toString(),
                            onRetry: _refresh,
                          )
                        else if (!snapshot.hasData || snapshot.data!.isEmpty)
                          _EmptyProjectsState(
                            onCreateProject: () => _openProjectEditor(),
                          )
                        else
                          FutureBuilder<Map<String, List<ProjectMemberModel>>>(
                            future: _loadMembersForProjects(snapshot.data!),
                            builder: (context, memberSnapshot) {
                              final membersByProject =
                                  memberSnapshot.data ??
                                  const <String, List<ProjectMemberModel>>{};

                              return _ProjectDashboardContent(
                                projects: snapshot.data!,
                                membersByProject: membersByProject,
                                onOpen: _openProject,
                                onEdit: _openProjectEditor,
                                onArchive: _archiveProject,
                                onDelete: _deleteProject,
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            )
          : _selectedDestination == 1
          ? ProjectTasksPage(repository: _repository)
          : const SizedBox.expand(),
    );
  }
}

class _ProjectBottomNavigation extends StatelessWidget {
  const _ProjectBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items =
      <({IconData icon, IconData selectedIcon, String label})>[
        (
          icon: Icons.folder_outlined,
          selectedIcon: Icons.folder_rounded,
          label: 'Projects',
        ),
        (
          icon: Icons.check_circle_outline_rounded,
          selectedIcon: Icons.check_circle_rounded,
          label: 'Tasks',
        ),
        (
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month_rounded,
          label: 'Calendar',
        ),
        (
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart_rounded,
          label: 'Reports',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        border: Border(top: BorderSide(color: AppPalette.border(context))),
        boxShadow: [
          BoxShadow(
            color: AppPalette.softShadow(context),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 8 + bottomInset),
        child: Row(
          children: [
            for (var index = 0; index < _items.length; index++)
              Expanded(
                child: _ProjectNavigationItem(
                  icon: selectedIndex == index
                      ? _items[index].selectedIcon
                      : _items[index].icon,
                  label: _items[index].label,
                  selected: selectedIndex == index,
                  color: theme.colorScheme.primary,
                  onTap: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProjectNavigationItem extends StatelessWidget {
  const _ProjectNavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = AppPalette.mutedText(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, size: 22, color: selected ? color : muted),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? color : muted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectsHeader extends StatelessWidget {
  const _ProjectsHeader({
    required this.projectCount,
    required this.onBack,
    required this.onNotifications,
  });

  final int projectCount;
  final VoidCallback onBack;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderActionButton(icon: Icons.arrow_back_rounded, onTap: onBack),
        const SizedBox(width: 14),
        Text(
          'Projects',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3D7F).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$projectCount',
            style: const TextStyle(
              color: Color(0xFFFF3D7F),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.search_rounded, size: 28),
          tooltip: 'Search',
        ),
        _HeaderActionButton(
          icon: Icons.notifications_none_rounded,
          onTap: onNotifications,
        ),
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface = AppPalette.surface(context);
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppPalette.border(context)),
            boxShadow: [
              BoxShadow(
                color: AppPalette.softShadow(context),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon),
        ),
      ),
    );
  }
}

class _ProjectDashboardContent extends StatelessWidget {
  const _ProjectDashboardContent({
    required this.projects,
    required this.membersByProject,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final List<ProjectModel> projects;
  final Map<String, List<ProjectMemberModel>> membersByProject;
  final ValueChanged<ProjectModel> onOpen;
  final ValueChanged<ProjectModel> onEdit;
  final ValueChanged<ProjectModel> onArchive;
  final ValueChanged<ProjectModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final done = projects.fold<int>(
      0,
      (sum, p) => sum + (p.summary?.doneTasks ?? 0),
    );
    final progress = projects.fold<int>(
      0,
      (sum, p) => sum + (p.summary?.inProgressTasks ?? 0),
    );
    final onHold = projects
        .where((p) => p.status == ProjectStatus.onHold)
        .length;
    final totalTasks = projects.fold<int>(
      0,
      (sum, p) => sum + (p.summary?.totalTasks ?? 0),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardPanel(
          child: Column(
            children: [
              const _SectionTitle(title: 'Overview', action: 'This Week'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.folder_rounded,
                      value: projects.length,
                      label: 'Projects',
                      color: Color(0xFFFF3D7F),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.check_rounded,
                      value: done,
                      label: 'Tasks Done',
                      color: Color(0xFF7557F7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.schedule_rounded,
                      value: progress,
                      label: 'In Progress',
                      color: Color(0xFFFF9417),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.flag_rounded,
                      value: onHold,
                      label: 'On Hold',
                      color: Color(0xFF19B96B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          title: 'My Projects',
          action: 'View all',
          accentAction: true,
        ),
        const SizedBox(height: 12),
        for (final project in projects.take(4)) ...[
          _DashboardProjectCard(
            project: project,
            members: membersByProject[project.id] ?? const [],
            onTap: () => onOpen(project),
            onEdit: () => onEdit(project),
            onArchive: () => onArchive(project),
            onDelete: () => onDelete(project),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _PriorityPanel(total: totalTasks)),
            const SizedBox(width: 12),
            const Expanded(child: _DueSoonPanel()),
          ],
        ),
        const SizedBox(height: 16),
        const _CalendarPanel(),
      ],
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppPalette.surface(context),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppPalette.border(context)),
      boxShadow: [
        BoxShadow(
          color: AppPalette.softShadow(context),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.action,
    this.accentAction = false,
  });
  final String title;
  final String action;
  final bool accentAction;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      Text(
        action,
        style: TextStyle(
          color: accentAction
              ? const Color(0xFFFF3D7F)
              : AppPalette.mutedText(context),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      if (!accentAction)
        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
    ],
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    height: 142,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
    decoration: BoxDecoration(
      color: AppPalette.surfaceAlt(context),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        Text(
          value == 0 ? '—' : '↑ ${value > 9 ? 12 : value}%',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _DashboardProjectCard extends StatelessWidget {
  const _DashboardProjectCard({
    required this.project,
    required this.members,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });
  final ProjectModel project;
  final List<ProjectMemberModel> members;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final color = projectStatusColor(project.status);
    final progress = (project.summary?.completionPercent ?? 0)
        .clamp(0, 100)
        .toDouble();
    return Material(
      color: AppPalette.surface(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppPalette.border(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.folder_copy_rounded, color: color, size: 29),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _ProjectMenu(
                          onEdit: onEdit,
                          onArchive: onArchive,
                          onDelete: onDelete,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              minHeight: 5,
                              color: color,
                              backgroundColor: AppPalette.surfaceAlt(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${progress.round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        _MemberRibbon(members: members),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Due ${formatShortDate(project.targetEndDate)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppPalette.mutedText(context),
                            ),
                          ),
                        ),
                        _StatusPill(
                          label: formatStatusLabel(project.status),
                          color: color,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectMenu extends StatelessWidget {
  const _ProjectMenu({
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    padding: EdgeInsets.zero,
    icon: Icon(
      Icons.more_vert_rounded,
      color: AppPalette.mutedText(context),
      size: 20,
    ),
    onSelected: (v) => v == 'edit'
        ? onEdit()
        : v == 'archive'
        ? onArchive()
        : onDelete(),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'edit', child: Text('Edit project')),
      PopupMenuItem(value: 'archive', child: Text('Archive project')),
      PopupMenuItem(value: 'delete', child: Text('Delete project')),
    ],
  );
}

class _PriorityPanel extends StatelessWidget {
  const _PriorityPanel({required this.total});
  final int total;
  @override
  Widget build(BuildContext context) => _DashboardPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tasks by Priority',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        Center(
          child: SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: .72,
                  strokeWidth: 11,
                  color: const Color(0xFFFF3D7F),
                  backgroundColor: const Color(0xFF35C58A),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const Text('Total', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _Legend(color: Color(0xFFFF3D7F), text: 'High'),
        const _Legend(color: Color(0xFFFF9417), text: 'Medium'),
        const _Legend(color: Color(0xFF19B96B), text: 'Low'),
      ],
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}

class _DueSoonPanel extends StatelessWidget {
  const _DueSoonPanel();
  @override
  Widget build(BuildContext context) => _DashboardPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Tasks Due Soon',
          action: 'View all',
          accentAction: true,
        ),
        const SizedBox(height: 14),
        const _DueRow('Review UI/UX', 'Today', Color(0xFFFF3D7F)),
        const _DueRow('Client Meeting', 'Tomorrow', Color(0xFFFF9417)),
        const _DueRow('Prototype Testing', '12 May', Color(0xFF19B96B)),
        const _DueRow('Launch Plan', '15 May', Color(0xFF7557F7)),
      ],
    ),
  );
}

class _DueRow extends StatelessWidget {
  const _DueRow(this.title, this.date, this.color);
  final String title;
  final String date;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
        Text(
          date,
          style: TextStyle(fontSize: 10, color: AppPalette.mutedText(context)),
        ),
      ],
    ),
  );
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel();
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return _DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Upcoming Calendar',
            action: 'View calendar',
            accentAction: true,
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < 7; i++)
                _CalendarDay(
                  date: now.add(Duration(days: i)),
                  selected: i == 1,
                ),
            ],
          ),
          const Divider(height: 28),
          const _EventRow(
            color: Color(0xFFFF3D7F),
            title: 'Project Standup',
            time: '10:00 AM – 10:30 AM',
          ),
          const SizedBox(height: 14),
          const _EventRow(
            color: Color(0xFF7557F7),
            title: 'Client Meeting',
            time: '02:00 PM – 03:00 PM',
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.date, required this.selected});
  final DateTime date;
  final bool selected;
  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
    decoration: BoxDecoration(
      color: selected ? const Color(0xFFFF3D7F).withValues(alpha: .12) : null,
      borderRadius: BorderRadius.circular(12),
      border: selected ? Border.all(color: const Color(0xFFFF3D7F)) : null,
    ),
    child: Column(
      children: [
        Text(
          days[date.weekday - 1],
          style: TextStyle(fontSize: 10, color: AppPalette.mutedText(context)),
        ),
        const SizedBox(height: 5),
        Text(
          '${date.day}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.color,
    required this.title,
    required this.time,
  });
  final Color color;
  final String title;
  final String time;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: AppPalette.mutedText(context),
            ),
          ),
        ],
      ),
    ],
  );
}

// Retained while project detail actions migrate to the new compact card.
// ignore: unused_element
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.members,
    required this.onTap,
    required this.onAddMember,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final ProjectModel project;
  final List<ProjectMemberModel> members;
  final VoidCallback onTap;
  final VoidCallback onAddMember;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = AppPalette.surface(context);
    final muted = AppPalette.mutedText(context);
    final daysPassed = _daysPassed(project.startDate);
    final statusColor = projectStatusColor(project.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppPalette.border(context)),
            boxShadow: [
              BoxShadow(
                color: AppPalette.softShadow(context),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatusPill(
                            label: formatStatusLabel(project.status),
                            color: statusColor,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            project.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CardIconButton(
                      icon: Icons.person_add_alt_1_rounded,
                      tooltip: 'Add member',
                      onTap: onAddMember,
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      tooltip: 'Project actions',
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'archive') {
                          onArchive();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit project'),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Text('Archive project'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete project'),
                        ),
                      ],
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppPalette.surfaceAlt(context),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.more_horiz_rounded),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  project.description.trim().isEmpty
                      ? 'No description added yet.'
                      : project.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoChip(
                      icon: Icons.play_arrow_rounded,
                      label: 'Start ${formatShortDate(project.startDate)}',
                    ),
                    _InfoChip(
                      icon: Icons.flag_rounded,
                      label: 'End ${formatShortDate(project.targetEndDate)}',
                    ),
                    _InfoChip(
                      icon: Icons.timelapse_rounded,
                      label: daysPassed == null
                          ? 'Timeline not started'
                          : '$daysPassed day${daysPassed == 1 ? '' : 's'} passed',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'People',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _MemberRibbon(members: members),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${members.length}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            members.length == 1 ? 'member' : 'members',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int? _daysPassed(DateTime? startDate) {
    if (startDate == null) return null;
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final today = DateTime.now();
    final current = DateTime(today.year, today.month, today.day);
    if (current.isBefore(start)) return 0;
    return current.difference(start).inDays;
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppPalette.surfaceAlt(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = AppPalette.mutedText(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRibbon extends StatelessWidget {
  const _MemberRibbon({required this.members});

  final List<ProjectMemberModel> members;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text(
        'No members yet',
        style: TextStyle(color: AppPalette.mutedText(context)),
      );
    }

    final visibleMembers = members.take(4).toList();
    final remaining = members.length - visibleMembers.length;
    final avatarCount = visibleMembers.length + (remaining > 0 ? 1 : 0);

    return SizedBox(
      width: 34 + ((avatarCount - 1) * 24),
      height: 34,
      child: Stack(
        children: [
          for (var i = 0; i < visibleMembers.length; i++)
            Positioned(
              left: i * 24,
              child: _MemberAvatar(member: visibleMembers[i]),
            ),
          if (remaining > 0)
            Positioned(
              left: visibleMembers.length * 24,
              child: _OverflowAvatar(count: remaining),
            ),
        ],
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member});

  final ProjectMemberModel member;

  @override
  Widget build(BuildContext context) {
    final label = member.profile?.memberName ?? 'Member';
    final initials = _initials(label);
    final color = _colorFromSeed(label);

    return Tooltip(
      message: label,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppPalette.surface(context), width: 2.5),
        ),
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Color _colorFromSeed(String seed) {
    final colors = <Color>[
      const Color(0xFF6C63FF),
      const Color(0xFF20B486),
      const Color(0xFFFF8A5B),
      const Color(0xFF4C8DFF),
      const Color(0xFFE967A3),
      const Color(0xFF7DCC5A),
    ];
    return colors[seed.hashCode.abs() % colors.length];
  }
}

class _OverflowAvatar extends StatelessWidget {
  const _OverflowAvatar({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt(context),
        shape: BoxShape.circle,
        border: Border.all(color: AppPalette.surface(context), width: 2.5),
      ),
      child: Text(
        '+$count',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ProjectsLoadingState extends StatelessWidget {
  const _ProjectsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              color: AppPalette.surface(context),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppPalette.border(context)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectsErrorState extends StatelessWidget {
  const _ProjectsErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppPalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Could not load projects',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: AppPalette.mutedText(context))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => onRetry(),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _EmptyProjectsState extends StatelessWidget {
  const _EmptyProjectsState({required this.onCreateProject});

  final VoidCallback onCreateProject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppPalette.border(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppPalette.surfaceAlt(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.dashboard_customize_rounded,
              size: 34,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No projects yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first project and this space will turn into a clean, trackable workspace.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.mutedText(context),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreateProject,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create project'),
          ),
        ],
      ),
    );
  }
}

class _AddProjectMemberSheet extends StatefulWidget {
  const _AddProjectMemberSheet({
    required this.project,
    required this.repository,
  });

  final ProjectModel project;
  final ProjectManagementRepository repository;

  @override
  State<_AddProjectMemberSheet> createState() => _AddProjectMemberSheetState();
}

class _AddProjectMemberSheetState extends State<_AddProjectMemberSheet> {
  final _searchController = TextEditingController();
  List<UserProfileModel> _results = const [];
  List<ProjectMemberModel> _members = const [];
  ProjectMemberRole _selectedRole = ProjectMemberRole.member;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await widget.repository.getProjectMembers(
        widget.project.id,
      );
      if (!mounted) return;
      setState(() => _members = members);
    } catch (_) {
      // Keep sheet usable even if the current member list fails to load.
    }
  }

  Future<void> _searchUsers(String value) async {
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final results = await widget.repository
          .searchRegisteredUsersForProjectMemberAdd(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addMember(UserProfileModel user) async {
    if (_members.any((member) => member.userId == user.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.displayName} is already in this project.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repository.addProjectMember(
        projectId: widget.project.id,
        userId: user.id,
        role: _selectedRole,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.displayName} added to ${widget.project.name}.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final muted = AppPalette.mutedText(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, inset + 24),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            'Add member',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite an existing app user to "${widget.project.name}" and set their role.',
            style: TextStyle(color: muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<ProjectMemberRole>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(labelText: 'Project role'),
            items: ProjectMemberRole.values
                .where((role) => role != ProjectMemberRole.owner)
                .map(
                  (role) => DropdownMenuItem(
                    value: role,
                    child: Text(_roleLabel(role)),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _selectedRole = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            enabled: !_saving,
            decoration: InputDecoration(
              labelText: 'Search by name or email',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _results = const []);
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_searchController.text.trim().length < 2)
            Text(
              'Start typing at least 2 characters to find registered users.',
              style: TextStyle(color: muted),
            )
          else if (_results.isEmpty && !_loading)
            Text('No matching users found.', style: TextStyle(color: muted))
          else
            Column(
              children: [
                for (final user in _results)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SearchResultTile(
                      user: user,
                      alreadyAdded: _members.any(
                        (member) => member.userId == user.id,
                      ),
                      busy: _saving,
                      onAdd: () => _addMember(user),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _roleLabel(ProjectMemberRole role) => switch (role) {
    ProjectMemberRole.admin => 'Admin',
    ProjectMemberRole.member => 'Member',
    ProjectMemberRole.viewer => 'Viewer',
    ProjectMemberRole.owner => 'Owner',
  };
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.user,
    required this.alreadyAdded,
    required this.busy,
    required this.onAdd,
  });

  final UserProfileModel user;
  final bool alreadyAdded;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.border(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.14),
            child: Text(
              _initials(user.displayName),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if ((user.email ?? '').isNotEmpty)
                  Text(
                    user.email!,
                    style: TextStyle(color: AppPalette.mutedText(context)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (alreadyAdded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppPalette.surfaceAlt(context),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Added',
                style: TextStyle(
                  color: AppPalette.mutedText(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            FilledButton(
              onPressed: busy ? null : onAdd,
              child: const Text('Add'),
            ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
