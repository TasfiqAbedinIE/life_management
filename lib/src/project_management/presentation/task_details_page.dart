import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../data/project_management_realtime.dart';
import '../data/project_management_repository.dart';
import '../models/project_management_models.dart';
import 'project_management_editors.dart';

class TaskDetailsPage extends StatefulWidget {
  const TaskDetailsPage({
    super.key,
    required this.task,
    required this.repository,
    required this.members,
  });

  final TaskModel task;
  final ProjectManagementRepository repository;
  final List<ProjectMemberModel> members;

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  final _commentController = TextEditingController();
  final _realtime = ProjectRealtimeSubscriptions();
  RealtimeChannel? _commentsChannel;
  late TaskModel _task;
  late Future<List<TaskCommentModel>> _commentsFuture;
  late Future<List<TaskAttachmentModel>> _attachmentsFuture;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _commentsFuture = widget.repository.getTaskComments(_task.id);
    _attachmentsFuture = widget.repository.getTaskAttachments(_task.id);
    _commentsChannel = _realtime.subscribeToTaskComments(
      taskId: _task.id,
      onEvent: (_) {
        if (!mounted) return;
        setState(() {
          _commentsFuture = widget.repository.getTaskComments(_task.id);
        });
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    if (_commentsChannel != null) {
      _realtime.disposeChannel(_commentsChannel!);
    }
    super.dispose();
  }

  Future<void> _changeStatus(TaskStatus status) async {
    try {
      final updated = await widget.repository.updateTask(
        taskId: _task.id,
        status: status,
        progressPercent: status == TaskStatus.done
            ? 100
            : _task.progressPercent,
      );
      if (!mounted) return;
      setState(() => _task = updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _editTask() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => TaskEditorSheet(
        projectId: _task.projectId,
        repository: widget.repository,
        members: widget.members,
        task: _task,
      ),
    );
    if (changed == true) {
      final refreshed = await widget.repository.getProjectTasks(
        projectId: _task.projectId,
      );
      final updated = refreshed.firstWhere(
        (task) => task.id == _task.id,
        orElse: () => _task,
      );
      if (!mounted) return;
      setState(() => _task = updated);
    }
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete task'),
        content: Text('Delete "${_task.title}"?'),
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
      await widget.repository.deleteTask(_task.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _posting = true);
    try {
      await widget.repository.addComment(
        taskId: _task.id,
        commentText: _commentController.text,
      );
      _commentController.clear();
      if (!mounted) return;
      setState(
        () => _commentsFuture = widget.repository.getTaskComments(_task.id),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignee = widget.members
        .where((member) => member.userId == _task.assigneeId)
        .firstOrNull;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4EF),
        title: const Text('Task Details'),
        actions: [
          IconButton(
            onPressed: _editTask,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            onPressed: _deleteTask,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
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
                Text(
                  _task.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _task.description.isEmpty
                      ? 'No description yet.'
                      : _task.description,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      label: formatTaskStatusLabel(_task.status),
                      color: taskStatusColor(_task.status),
                      darkText: _task.status != TaskStatus.done,
                    ),
                    _InfoChip(
                      label: _task.priority.name.toUpperCase(),
                      color: taskPriorityColor(_task.priority),
                      darkText: true,
                    ),
                    _InfoChip(
                      label: 'Due ${formatShortDate(_task.dueDate)}',
                      color: const Color(0xFFF0F1F4),
                      darkText: true,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (_task.progressPercent / 100).clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: Colors.black.withValues(alpha: 0.07),
                          color: const Color(0xFF24C49C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('${_task.progressPercent}%'),
                  ],
                ),
                const SizedBox(height: 14),
                if (assignee != null)
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFEFE9DF),
                        child: Text(
                          (assignee.profile?.memberName ?? 'Member')
                              .substring(0, 1)
                              .toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(assignee.profile?.memberName ?? 'Member'),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TaskStatus.values.map((status) {
                    final selected = _task.status == status;
                    return InkWell(
                      onTap: () => _changeStatus(status),
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? taskStatusColor(status)
                              : const Color(0xFFF0F1F4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          formatTaskStatusLabel(status),
                          style: TextStyle(
                            color: selected && status == TaskStatus.done
                                ? Colors.white
                                : const Color(0xFF171717),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Task Timeline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                _TimelineBar(
                  label: 'Start',
                  color: const Color(0xFFFF6A3D),
                  value: formatShortDate(_task.startDate),
                ),
                const SizedBox(height: 10),
                _TimelineBar(
                  label: 'Review',
                  color: const Color(0xFF24C49C),
                  value: formatTaskStatusLabel(_task.status),
                ),
                const SizedBox(height: 10),
                _TimelineBar(
                  label: 'Deadline',
                  color: const Color(0xFF8E86FF),
                  value: formatShortDate(_task.dueDate),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attachments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<TaskAttachmentModel>>(
                  future: _attachmentsFuture,
                  builder: (context, snapshot) {
                    final attachments =
                        snapshot.data ?? const <TaskAttachmentModel>[];
                    if (attachments.isEmpty) {
                      return const Text('No attachments uploaded yet.');
                    }
                    return Column(
                      children: attachments
                          .map(
                            (attachment) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(attachment.fileName),
                              subtitle: Text(attachment.storagePath),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write a comment',
                    suffixIcon: IconButton(
                      onPressed: _posting ? null : _addComment,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<TaskCommentModel>>(
                  future: _commentsFuture,
                  builder: (context, snapshot) {
                    final comments =
                        snapshot.data ?? const <TaskCommentModel>[];
                    if (comments.isEmpty) return const Text('No comments yet.');
                    return Column(
                      children: comments
                          .map(
                            (comment) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F4EF),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comment.commentText),
                                  const SizedBox(height: 6),
                                  Text(
                                    comment.createdAt
                                        .toLocal()
                                        .toString()
                                        .split('.')
                                        .first,
                                    style: TextStyle(
                                      color: AppPalette.mutedText(context),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.color,
    required this.darkText,
  });
  final String label;
  final Color color;
  final bool darkText;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: darkText ? const Color(0xFF171717) : Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimelineBar extends StatelessWidget {
  const _TimelineBar({
    required this.label,
    required this.color,
    required this.value,
  });
  final String label;
  final Color color;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(value),
          ),
        ),
      ],
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
