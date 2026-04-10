import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/project_management_repository.dart';
import '../models/project_management_models.dart';
import 'project_details_page.dart';
import 'project_management_editors.dart';

class ProjectManagementPage extends StatefulWidget {
  const ProjectManagementPage({super.key});

  @override
  State<ProjectManagementPage> createState() => _ProjectManagementPageState();
}

class _ProjectManagementPageState extends State<ProjectManagementPage> {
  final _repository = ProjectManagementRepository();

  late Future<List<ProjectModel>> _projectsFuture;

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
      builder: (_) => ProjectEditorSheet(
        repository: _repository,
        project: project,
      ),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _openProject(ProjectModel project) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProjectDetailsPage(
          projectId: project.id,
          repository: _repository,
        ),
      ),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _openMemberEditor(ProjectModel project) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _AddProjectMemberSheet(
        project: project,
        repository: _repository,
      ),
    );
    if (changed == true) {
      await _refresh();
    }
  }

  Future<void> _archiveProject(ProjectModel project) async {
    try {
      await _repository.archiveProject(project.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${project.name}" archived.')),
      );
      await _refresh();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${project.name}" deleted.')),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openProjectEditor(),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: SafeArea(
        child: FutureBuilder<List<ProjectModel>>(
          future: _projectsFuture,
          builder: (context, snapshot) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                children: [
                  _ProjectsHeader(
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
                  const SizedBox(height: 24),
                  Text(
                    'Projects',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A clean overview of every project, its timeline, status, and team.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppPalette.mutedText(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
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

                        return Column(
                          children: [
                            for (final project in snapshot.data!)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _ProjectCard(
                                  project: project,
                                  members:
                                      membersByProject[project.id] ??
                                      const <ProjectMemberModel>[],
                                  onTap: () => _openProject(project),
                                  onAddMember: () => _openMemberEditor(project),
                                  onEdit: () => _openProjectEditor(project),
                                  onArchive: () => _archiveProject(project),
                                  onDelete: () => _deleteProject(project),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProjectsHeader extends StatelessWidget {
  const _ProjectsHeader({
    required this.onBack,
    required this.onNotifications,
  });

  final VoidCallback onBack;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderActionButton(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
        const Spacer(),
        _HeaderActionButton(
          icon: Icons.notifications_none_rounded,
          onTap: onNotifications,
        ),
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.onTap,
  });

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
          width: 52,
          height: 52,
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
  const _StatusPill({
    required this.label,
    required this.color,
  });

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
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

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
  const _MemberRibbon({
    required this.members,
  });

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

    return SizedBox(
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
  const _MemberAvatar({
    required this.member,
  });

  final ProjectMemberModel member;

  @override
  Widget build(BuildContext context) {
    final label = member.profile?.displayName ?? member.userId;
    final initials = _initials(label);
    final color = _colorFromSeed(label);

    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppPalette.surface(context),
          width: 2.5,
        ),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
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
  const _OverflowAvatar({
    required this.count,
  });

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
        border: Border.all(
          color: AppPalette.surface(context),
          width: 2.5,
        ),
      ),
      child: Text(
        '+$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
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
  const _ProjectsErrorState({
    required this.message,
    required this.onRetry,
  });

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
          Text(
            message,
            style: TextStyle(color: AppPalette.mutedText(context)),
          ),
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
  const _EmptyProjectsState({
    required this.onCreateProject,
  });

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
      final members = await widget.repository.getProjectMembers(widget.project.id);
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
      final results = await widget.repository.searchRegisteredUsersForProjectMemberAdd(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addMember(UserProfileModel user) async {
    if (_members.any((member) => member.userId == user.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.displayName} is already in this project.')),
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
        SnackBar(content: Text('${user.displayName} added to ${widget.project.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite an existing app user to "${widget.project.name}" and set their role.',
            style: TextStyle(color: muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<ProjectMemberRole>(
            value: _selectedRole,
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
            Text(
              'No matching users found.',
              style: TextStyle(color: muted),
            )
          else
            Column(
              children: [
                for (final user in _results)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SearchResultTile(
                      user: user,
                      alreadyAdded: _members.any((member) => member.userId == user.id),
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
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
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
