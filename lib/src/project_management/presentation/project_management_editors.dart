import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../data/project_management_repository.dart';
import '../models/project_management_models.dart';

String formatShortDate(DateTime? value) {
  if (value == null) return 'Not set';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String formatStatusLabel(ProjectStatus status) => switch (status) {
      ProjectStatus.planning => 'Planning',
      ProjectStatus.active => 'Active',
      ProjectStatus.onHold => 'On Hold',
      ProjectStatus.completed => 'Completed',
      ProjectStatus.archived => 'Archived',
    };

String formatTaskStatusLabel(TaskStatus status) => switch (status) {
      TaskStatus.todo => 'To Do',
      TaskStatus.inProgress => 'In Progress',
      TaskStatus.review => 'Review',
      TaskStatus.done => 'Done',
    };

Color projectStatusColor(ProjectStatus status) => switch (status) {
      ProjectStatus.planning => const Color(0xFF8E86FF),
      ProjectStatus.active => const Color(0xFF24C49C),
      ProjectStatus.onHold => const Color(0xFFFFC75A),
      ProjectStatus.completed => const Color(0xFF5DD56F),
      ProjectStatus.archived => const Color(0xFF262626),
    };

Color taskStatusColor(TaskStatus status) => switch (status) {
      TaskStatus.todo => const Color(0xFFE9EBEF),
      TaskStatus.inProgress => const Color(0xFF24C49C),
      TaskStatus.review => const Color(0xFF8E86FF),
      TaskStatus.done => const Color(0xFF191919),
    };

Color taskPriorityColor(TaskPriority priority) => switch (priority) {
      TaskPriority.low => const Color(0xFF6FD37C),
      TaskPriority.medium => const Color(0xFFFFC75A),
      TaskPriority.high => const Color(0xFFFF8D6B),
      TaskPriority.urgent => const Color(0xFFFF5E5E),
    };

class ProjectEditorSheet extends StatefulWidget {
  const ProjectEditorSheet({
    super.key,
    required this.repository,
    this.project,
  });

  final ProjectManagementRepository repository;
  final ProjectModel? project;

  bool get isEditing => project != null;

  @override
  State<ProjectEditorSheet> createState() => _ProjectEditorSheetState();
}

class _ProjectEditorSheetState extends State<ProjectEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  ProjectStatus _status = ProjectStatus.planning;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    if (project != null) {
      _nameController.text = project.name;
      _descriptionController.text = project.description;
      _status = project.status;
      _startDate = project.startDate;
      _endDate = project.targetEndDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (widget.isEditing) {
        await widget.repository.updateProject(
          projectId: widget.project!.id,
          name: _nameController.text,
          description: _descriptionController.text,
          status: _status,
          startDate: _startDate,
          targetEndDate: _endDate,
        );
      } else {
        await widget.repository.createProject(
          name: _nameController.text,
          description: _descriptionController.text,
          status: _status,
          startDate: _startDate,
          targetEndDate: _endDate,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, inset + 24),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              widget.isEditing ? 'Edit Project' : 'Create Project',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Give it a clear name, status, and timeline so the dashboard can reflect real progress.',
              style: TextStyle(color: AppPalette.mutedText(context)),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Project name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Project name is required.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProjectStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: ProjectStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(formatStatusLabel(status)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _status = value ?? ProjectStatus.planning),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Start date',
                    value: formatShortDate(_startDate),
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateButton(
                    label: 'Target end',
                    value: formatShortDate(_endDate),
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Save Changes' : 'Create Project'),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({
    super.key,
    required this.projectId,
    required this.repository,
    required this.members,
    this.task,
  });

  final String projectId;
  final ProjectManagementRepository repository;
  final List<ProjectMemberModel> members;
  final TaskModel? task;

  bool get isEditing => task != null;

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _estimateController = TextEditingController();
  TaskStatus _status = TaskStatus.todo;
  TaskPriority _priority = TaskPriority.medium;
  String? _assigneeId;
  DateTime? _startDate;
  DateTime? _dueDate;
  int _progress = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      _estimateController.text = task.estimatedMinutes?.toString() ?? '';
      _status = task.status;
      _priority = task.priority;
      _assigneeId = task.assigneeId;
      _startDate = task.startDate;
      _dueDate = task.dueDate;
      _progress = task.progressPercent;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_dueDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_dueDate != null && _dueDate!.isBefore(picked)) {
          _dueDate = picked;
        }
      } else {
        _dueDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (widget.isEditing) {
        await widget.repository.updateTask(
          taskId: widget.task!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          status: _status,
          priority: _priority,
          assigneeId: _assigneeId,
          startDate: _startDate,
          dueDate: _dueDate,
          estimatedMinutes: int.tryParse(_estimateController.text.trim()),
          progressPercent: _progress,
        );
      } else {
        await widget.repository.createTask(
          projectId: widget.projectId,
          title: _titleController.text,
          description: _descriptionController.text,
          status: _status,
          priority: _priority,
          assigneeId: _assigneeId,
          startDate: _startDate,
          dueDate: _dueDate,
          estimatedMinutes: int.tryParse(_estimateController.text.trim()),
          progressPercent: _progress,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, inset + 24),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              widget.isEditing ? 'Edit Task' : 'Create Task',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Task title'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Task title is required.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Task description'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TaskStatus>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: TaskStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(formatTaskStatusLabel(status)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _status = value ?? TaskStatus.todo),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<TaskPriority>(
                    value: _priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: TaskPriority.values
                        .map(
                          (priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(priority.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _priority = value ?? TaskPriority.medium),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _assigneeId,
              decoration: const InputDecoration(labelText: 'Assignee'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Unassigned')),
                ...widget.members.map(
                  (member) => DropdownMenuItem<String?>(
                    value: member.userId,
                    child: Text(member.profile?.displayName ?? member.userId),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _assigneeId = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _estimateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Estimated minutes'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Start date',
                    value: formatShortDate(_startDate),
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateButton(
                    label: 'Due date',
                    value: formatShortDate(_dueDate),
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Progress $_progress%',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Slider(
              value: _progress.toDouble(),
              min: 0,
              max: 100,
              activeColor: taskStatusColor(_status),
              onChanged: (value) => setState(() => _progress = value.round()),
            ),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Save Task' : 'Create Task'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.surfaceAlt(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppPalette.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: AppPalette.mutedText(context), fontSize: 12)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
