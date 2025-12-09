import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final List<Map<String, dynamic>> _tasks = [];
  bool _loadingTasks = false;

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loadingTasks = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate); // 👈

      final res = await _supabase
          .from('tasks')
          .select('*')
          .eq('user_id', userId)
          .eq('start_date', dateStr) // 👈 filter by selected date
          .order('created_at', ascending: false);

      final tasksList = List<Map<String, dynamic>>.from(res as List);
      setState(() {
        _tasks
          ..clear()
          ..addAll(tasksList);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load tasks: $e')));
    } finally {
      if (mounted) setState(() => _loadingTasks = false);
    }
  }

  Future<void> _pickFilterDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadTasks(); // reload tasks for the new date
    }
  }

  void _resetToToday() async {
    setState(() {
      _selectedDate = DateTime.now();
    });
    await _loadTasks();
  }

  void _openAddTaskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddTaskSheet(
        onTaskSaved: (task) {
          setState(() {
            _tasks.insert(0, task); // insert newest at top
          });
        },
      ),
    );
  }

  Widget _buildEditBackground() {
    return Container(
      color: Colors.blueGrey.withOpacity(0.2),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Row(
        children: [
          Icon(Icons.edit, color: Colors.blueGrey),
          SizedBox(width: 8),
          Text('Edit', style: TextStyle(color: Colors.blueGrey)),
        ],
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      color: Colors.red.withOpacity(0.2),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Delete', style: TextStyle(color: Colors.red)),
          SizedBox(width: 8),
          Icon(Icons.delete_outline, color: Colors.red),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openEditTaskModal(Map<String, dynamic> task, int index) async {
    final updatedTask = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return AddTaskSheet(
          initialTask: task, // 👈 put the existing task here
          onTaskSaved: (t) {
            setState(() {
              _tasks[index] = t;
            });
          },
        );
      },
    );

    if (updatedTask != null) {
      setState(() {
        _tasks[index] = updatedTask;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Date filter row at the top
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFilterDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // TextButton(
                  //   onPressed: _resetToToday,
                  //   child: const Text('Today'),
                  // ),
                ],
              ),
            ),

            // 🔹 Main content (loader / empty / list)
            Expanded(
              child: _loadingTasks
                  ? const Center(child: CircularProgressIndicator())
                  : _tasks.isEmpty
                  ? const Center(child: Text('No tasks for this date.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index] as Map<String, dynamic>;
                        final taskId = task['id'];

                        return Dismissible(
                          // key for the whole row – tied to task id, not index
                          key: ValueKey('task_row_$taskId'),
                          direction: DismissDirection.horizontal,
                          background: _buildEditBackground(),
                          secondaryBackground: _buildDeleteBackground(),

                          // Only decide IF we should dismiss
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              // 👉 Swipe RIGHT: edit only, do NOT dismiss
                              await _openEditTaskModal(task, index);
                              return false;
                            }

                            if (direction == DismissDirection.endToStart) {
                              // 👈 Swipe LEFT: ask confirmation; actual delete in onDismissed
                              final shouldDelete = await _confirmDelete(
                                context,
                              );
                              return shouldDelete;
                            }

                            return false;
                          },

                          // 🔥 The actual delete (exactly once)
                          onDismissed: (direction) async {
                            try {
                              await _supabase
                                  .from('tasks')
                                  .delete()
                                  .eq('id', taskId);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete task: $e'),
                                  ),
                                );
                              }
                            }

                            if (mounted) {
                              setState(() {
                                _tasks.removeWhere((t) => t['id'] == taskId);
                              });
                            }
                          },

                          child: TaskCard(
                            // ❗ remove key here to avoid double-key confusion
                            task: task,
                            onTaskUpdated: (updatedTask) {
                              setState(() {
                                final updatedId = updatedTask['id'];
                                final idx = _tasks.indexWhere(
                                  (t) => t['id'] == updatedId,
                                );
                                if (idx != -1) {
                                  _tasks[idx] = updatedTask;
                                }
                              });
                            },
                            onTaskDeleted: () {
                              setState(() {
                                _tasks.removeWhere((t) => t['id'] == taskId);
                              });
                            },
                            onTaskCopied: (newTask) {
                              final startDateStr =
                                  newTask['start_date'] as String?;
                              if (startDateStr == null) return;

                              final newStart = DateTime.parse(startDateStr);
                              final newDateOnly = DateTime(
                                newStart.year,
                                newStart.month,
                                newStart.day,
                              );
                              final selectedDateOnly = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                              );

                              if (newDateOnly == selectedDateOnly) {
                                setState(() {
                                  _tasks.insert(0, newTask);
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTaskModal,
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }
}

class AddTaskSheet extends StatefulWidget {
  final void Function(Map<String, dynamic> task) onTaskSaved;

  /// If provided, the sheet works in EDIT mode; otherwise it creates a new task.
  final Map<String, dynamic>? initialTask;

  const AddTaskSheet({super.key, required this.onTaskSaved, this.initialTask});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _estimateCtrl = TextEditingController();
  String _label = 'OFFICE';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _saving = false;

  final SupabaseClient _supabase = Supabase.instance.client;

  bool get _isEditMode => widget.initialTask != null;

  @override
  void initState() {
    super.initState();

    // 🔁 If editing, pre-fill with existing task values
    final t = widget.initialTask;
    if (t != null) {
      _titleCtrl.text = (t['title'] ?? '').toString();
      _descCtrl.text = (t['description'] ?? '').toString();

      final est = t['estimated_minutes'];
      if (est != null) {
        _estimateCtrl.text = est.toString();
      }

      _label = (t['label'] ?? 'OFFICE').toString();

      try {
        if (t['start_date'] != null) {
          _startDate = DateTime.parse(t['start_date'] as String);
        }
        if (t['end_date'] != null) {
          _endDate = DateTime.parse(t['end_date'] as String);
        }
      } catch (_) {
        // if parsing fails, keep today's date
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _estimateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = picked;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      final estMinutes = int.tryParse(_estimateCtrl.text.trim());

      final payload = {
        'user_id': userId,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'label': _label,
        'estimated_minutes': estMinutes,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
        // status & total_spent_minutes handled elsewhere
      };

      late Map<String, dynamic> savedTask;

      if (_isEditMode) {
        // 🔧 EDIT MODE → UPDATE existing row
        final id = widget.initialTask!['id'];

        final res = await _supabase
            .from('tasks')
            .update({
              // we generally don't need to update user_id, but it's okay if you keep it
              'title': payload['title'],
              'description': payload['description'],
              'label': payload['label'],
              'estimated_minutes': payload['estimated_minutes'],
              'start_date': payload['start_date'],
              'end_date': payload['end_date'],
            })
            .eq('id', id)
            .select()
            .single();

        savedTask = Map<String, dynamic>.from(res as Map);
      } else {
        // 🆕 CREATE MODE → INSERT new row
        final res = await _supabase
            .from('tasks')
            .insert({...payload, 'status': 'pending'})
            .select()
            .single();

        savedTask = Map<String, dynamic>.from(res);
      }

      widget.onTaskSaved(savedTask);

      if (!mounted) return;
      Navigator.of(context).pop(); // close modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditMode ? 'Task updated' : 'Task added')),
      );
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Internet is not available, try again later'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save task: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dateFmt = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Text(
              _isEditMode ? 'Edit Task' : 'New Task',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Task title',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter a title'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _label,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'OFFICE', child: Text('OFFICE')),
                      DropdownMenuItem(value: 'HOME', child: Text('HOME')),
                      DropdownMenuItem(
                        value: 'PERSONAL',
                        child: Text('PERSONAL'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _label = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _estimateCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Estimated completion time (minutes)',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isStart: true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start date',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(dateFmt.format(_startDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isStart: false),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End date',
                              prefixIcon: Icon(Icons.event_outlined),
                            ),
                            child: Text(dateFmt.format(_endDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveTask,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEditMode ? 'Update' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskCard extends StatefulWidget {
  final Map<String, dynamic> task;
  final void Function(Map<String, dynamic> updatedTask) onTaskUpdated;
  final VoidCallback onTaskDeleted;
  final void Function(Map<String, dynamic> newTask) onTaskCopied;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
    required this.onTaskCopied,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard>
    with AutomaticKeepAliveClientMixin {
  late Map<String, dynamic> _task;
  late Duration _elapsed;
  Timer? _timer;
  bool _isRunning = false;

  DateTime? _lastTickTime;

  @override
  bool get wantKeepAlive => true;

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _task = Map<String, dynamic>.from(widget.task);

    // We now treat total_spent_minutes as "total_spent_seconds"
    final spentSeconds = (_task['total_spent_minutes'] ?? 0) as int;
    _elapsed = Duration(seconds: spentSeconds);

    _isRunning = _task['status'] == 'active';
    if (_isRunning) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Always keep latest data from parent
    _task = Map<String, dynamic>.from(widget.task);

    // If this card switched to a DIFFERENT task (id changed), re-init fully
    if (widget.task['id'] != oldWidget.task['id']) {
      final spentSeconds = _task['total_spent_minutes'] as int? ?? 0;
      _elapsed = Duration(seconds: spentSeconds);
      _isRunning = _task['status'] == 'active';
      return;
    }

    // Same task, parent may have updated it (e.g. status changed elsewhere)
    // 👉 DO NOT override elapsed time if timer is currently running
    if (!_isRunning) {
      final spentSeconds = _task['total_spent_minutes'] as int? ?? 0;
      _elapsed = Duration(seconds: spentSeconds);
      _isRunning = _task['status'] == 'active';
    }
  }

  @override
  void dispose() {
    // _timer?.cancel();
    _autoPauseAndSave();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _startTimer() {
    _timer?.cancel();
    _lastTickTime = DateTime.now(); // remember when we started/resumed

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final diff = now.difference(_lastTickTime ?? now);
      _lastTickTime = now;

      setState(() {
        // add the *actual* time passed (could be > 1 second if app was paused)
        _elapsed += diff;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _lastTickTime = null;
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isRunning) {
        _stopTimer();
        setState(() => _isRunning = false);

        // Save full seconds
        final spentSeconds = _elapsed.inSeconds;

        final res = await _supabase
            .from('tasks')
            .update({
              'status': 'pending',
              'total_spent_minutes': spentSeconds, // now actually seconds
            })
            .eq('id', _task['id'])
            .select()
            .single();

        setState(() => _task = Map<String, dynamic>.from(res as Map));
        widget.onTaskUpdated(_task);
      } else {
        // play → active
        setState(() => _isRunning = true);
        _startTimer();

        final res = await _supabase
            .from('tasks')
            .update({'status': 'active'})
            .eq('id', _task['id'])
            .select()
            .single();
        setState(() => _task = Map<String, dynamic>.from(res as Map));
        widget.onTaskUpdated(_task);
      }
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet. Try again later.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
    }
  }

  Future<void> _completeTask() async {
    try {
      _stopTimer();
      setState(() => _isRunning = false);

      final spentSeconds = _elapsed.inSeconds;

      final res = await _supabase
          .from('tasks')
          .update({
            'status': 'completed',
            'total_spent_minutes': spentSeconds, // treat as seconds
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _task['id'])
          .select()
          .single();

      setState(() => _task = Map<String, dynamic>.from(res as Map));
      widget.onTaskUpdated(_task);

      if (!mounted) return;
      final spentMinutesRounded = (spentSeconds / 60).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task completed. Spent: $spentMinutesRounded min'),
        ),
      );
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet. Try again later.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to complete task: $e')));
    }
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('tasks').delete().eq('id', _task['id']);
      widget.onTaskDeleted();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task deleted')));
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet. Try again later.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
    }
  }

  Future<void> _copyToDate() async {
    try {
      // Use current task's start date as initial date if available
      DateTime initialDate;
      final startDateStr = _task['start_date'] as String?;
      if (startDateStr != null) {
        initialDate = DateTime.tryParse(startDateStr) ?? DateTime.now();
      } else {
        initialDate = DateTime.now();
      }

      // 📅 Ask user which date to copy to
      final picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked == null) return; // user cancelled

      final targetDateStr = DateFormat('yyyy-MM-dd').format(picked);

      final payload = {
        'user_id': _task['user_id'],
        'title': _task['title'],
        'description': _task['description'],
        'label': _task['label'],
        'estimated_minutes': _task['estimated_minutes'],
        'start_date': targetDateStr,
        'end_date': targetDateStr,
        'status': 'pending',
        'total_spent_minutes': 0,
      };

      final res = await _supabase
          .from('tasks')
          .insert(payload)
          .select()
          .single();

      final newTask = Map<String, dynamic>.from(res as Map);
      widget.onTaskCopied(newTask);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Task copied to $targetDateStr')));
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet. Try again later.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to copy task: $e')));
    }
  }

  Future<void> _autoPauseAndSave() async {
    if (!_isRunning) return; // nothing to do if already paused

    _stopTimer();
    _isRunning = false;

    final spentSeconds = _elapsed.inSeconds;

    try {
      await _supabase
          .from('tasks')
          .update({
            'status': 'pending',
            'total_spent_minutes': spentSeconds, // still storing seconds
          })
          .eq('id', _task['id']);
      // No SnackBars here — we're leaving the page, context may be gone
    } catch (_) {
      // You can log the error if you want, but avoid using context here
    }
  }

  Future<void> _editSpentTime() async {
    // If it's running, safer to ask user to pause first
    if (_isRunning) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pause the task before editing spent time.'),
        ),
      );
      return;
    }

    final currentMinutes = _elapsed.inMinutes;
    final controller = TextEditingController(
      text: currentMinutes > 0 ? currentMinutes.toString() : '',
    );

    final editedMinutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit spent time'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Spent time (minutes)',
            hintText: 'e.g. 45',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final raw = controller.text.trim();
              final value = int.tryParse(raw);
              // If invalid, just close without applying
              if (value == null || value < 0) {
                Navigator.of(ctx).pop();
              } else {
                Navigator.of(ctx).pop(value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (editedMinutes == null) return; // user cancelled

    final spentSeconds = editedMinutes * 60;

    try {
      // Update local state first
      setState(() {
        _elapsed = Duration(seconds: spentSeconds);
      });

      // Save to Supabase (still using this column as "seconds")
      final res = await _supabase
          .from('tasks')
          .update({'total_spent_minutes': spentSeconds})
          .eq('id', _task['id'])
          .select()
          .single();

      setState(() {
        _task = Map<String, dynamic>.from(res as Map);
      });

      widget.onTaskUpdated(_task);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Spent time updated')));
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet. Try again later.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update spent time: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final title = _task['title'] ?? '';
    final description = (_task['description'] ?? '').toString();
    final label = _task['label'] ?? '';
    final estimated = _task['estimated_minutes'] as int?;
    final status = (_task['status'] ?? 'pending') as String;

    Color labelColor;
    switch (label) {
      case 'OFFICE':
        labelColor = Colors.indigo;
        break;
      case 'HOME':
        labelColor = Colors.green;
        break;
      case 'PERSONAL':
        labelColor = Colors.deepOrange;
        break;
      default:
        labelColor = Colors.grey;
    }

    IconData statusIcon;
    Color statusColor;
    switch (status) {
      case 'active':
        statusIcon = Icons.play_arrow_rounded;
        statusColor = Colors.green;
        break;
      case 'completed':
        statusIcon = Icons.check_circle;
        statusColor = Colors.blueGrey;
        break;
      default:
        statusIcon = Icons.radio_button_unchecked;
        statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: title + status icon
          Row(
            children: [
              Icon(statusIcon, size: 18, color: statusColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2: description if any
          if (description.trim().isNotEmpty) ...[
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 6),
          ],
          // Row 3: label + estimated time
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: labelColor.withOpacity(0.08),
                ),
                child: Text(
                  label.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (estimated != null)
                Text(
                  'Est: $estimated min',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 4: spent time + all buttons in a single row
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _editSpentTime,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Spent: ${_formatDuration(_elapsed)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        decoration:
                            TextDecoration.none, // optional hint it's tappable
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: _isRunning ? 'Pause' : 'Start',
                onPressed: status == 'completed' ? null : _togglePlayPause,
                icon: Icon(
                  _isRunning
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: status == 'completed'
                      ? Colors.grey
                      : (_isRunning ? Colors.orange : Colors.green),
                ),
              ),
              IconButton(
                tooltip: 'Complete',
                onPressed: status == 'completed' ? null : _completeTask,
                icon: const Icon(Icons.check_circle, color: Colors.blueGrey),
              ),
              IconButton(
                tooltip: 'Copy to next day',
                onPressed: _copyToDate,
                icon: const Icon(
                  Icons.copy_all_outlined,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
