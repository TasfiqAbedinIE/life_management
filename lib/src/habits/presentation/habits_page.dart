// lib/features/habits/presentation/habits_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/habit_repository.dart';
import '../models/habit.dart';
import '../models/habit_entry.dart';
import 'widgets/habit_card.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  late final HabitRepository _repo;
  bool _loading = true;
  List<Habit> _habits = [];

  // cache entries & expanded states
  final Map<String, List<HabitEntry>> _entries = {};
  final Set<String> _expandedHabits = {};

  @override
  void initState() {
    super.initState();
    _repo = HabitRepository(Supabase.instance.client);
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    setState(() => _loading = true);

    try {
      final habits = await _repo.fetchHabits();

      // ✅ batch load entries for all habits so cards show correct 0/freq immediately
      final ids = habits.map((h) => h.id).toList();
      final entriesMap = await _repo.fetchEntriesForHabits(habitIds: ids);

      setState(() {
        _habits = habits;
        _entries
          ..clear()
          ..addAll(entriesMap);
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshEntries(String habitId) async {
    final entries = await _repo.fetchEntriesForHabit(habitId: habitId);
    setState(() {
      _entries[habitId] = entries;
    });
  }

  Future<void> _increment(Habit habit) async {
    await _repo.incrementToday(habit: habit);
    await _refreshEntries(habit.id);
  }

  Future<void> _decrement(Habit habit) async {
    await _repo.decrementToday(habit: habit);
    await _refreshEntries(habit.id);
  }

  Future<void> _onExpand(Habit habit) async {
    final isOpen = _expandedHabits.contains(habit.id);

    setState(() {
      if (isOpen) {
        _expandedHabits.remove(habit.id);
      } else {
        _expandedHabits.add(habit.id);
      }
    });

    // Load entries when expanding (so heatmap + streak has data)
    if (!isOpen) {
      await _refreshEntries(habit.id);
    }
  }

  Future<void> _deleteHabit(Habit habit) async {
    // HabitCard already confirms delete before dismissing,
    // but we keep this safe if you call delete elsewhere.
    await _repo.deleteHabit(habit.id);

    setState(() {
      _habits.removeWhere((h) => h.id == habit.id);
      _entries.remove(habit.id);
      _expandedHabits.remove(habit.id);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Habit deleted')));
  }

  Future<void> _showEditHabitSheet(Habit habit) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddHabitSheet(
        initialName: habit.name,
        initialFrequency: habit.frequencyPerDay,
        initialColorHex: habit.colorHex,
        title: 'Edit Habit',
        buttonText: 'Update habit',
      ),
    );

    if (result == null) return;

    final updated = await _repo.updateHabit(
      habitId: habit.id,
      name: result['name'] as String,
      frequencyPerDay: result['frequency'] as int,
      colorHex: result['color'] as String?,
    );

    setState(() {
      final idx = _habits.indexWhere((h) => h.id == habit.id);
      if (idx != -1) _habits[idx] = updated;
    });

    // refresh entries because frequency change affects heatmap intensity + streak
    await _refreshEntries(habit.id);
  }

  Future<void> _showAddHabitSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddHabitSheet(),
    );

    if (result != null) {
      final newHabit = await _repo.createHabit(
        // user_id: userId,
        name: result['name'] as String,
        frequencyPerDay: result['frequency'] as int,
        colorHex: result['color'] as String?,
      );
      setState(() {
        _habits.insert(0, newHabit);
        _entries[newHabit.id] = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Habits'), elevation: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddHabitSheet,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHabits,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _habits.isEmpty
            ? const Center(child: Text("Let's start a new habit ✨"))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _habits.length,
                itemBuilder: (context, index) {
                  final habit = _habits[index];
                  final entries = _entries[habit.id] ?? [];
                  final isExpanded = _expandedHabits.contains(habit.id);
                  return HabitCard(
                    habit: habit,
                    entries: entries,
                    isExpanded: isExpanded,
                    onIncrementToday: () => _increment(habit),
                    onDecrementToday: () => _decrement(habit),
                    onToggleExpand: () => _onExpand(habit),
                    onEdit: () => _showEditHabitSheet(habit),
                    onDelete: () => _deleteHabit(habit),
                  );
                },
              ),
      ),
    );
  }
}

class _AddHabitSheet extends StatefulWidget {
  final String? initialName;
  final int? initialFrequency;
  final String? initialColorHex;

  final String title;
  final String buttonText;

  const _AddHabitSheet({
    this.initialName,
    this.initialFrequency,
    this.initialColorHex,
    this.title = 'New Habit',
    this.buttonText = 'Save habit',
  });

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;

  late int _frequency;
  String? _selectedColorHex;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _frequency = widget.initialFrequency ?? 1;
    _selectedColorHex = widget.initialColorHex;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'name': _nameCtrl.text.trim(),
      'frequency': _frequency,
      'color': _selectedColorHex,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final colors = ['#FF6B6B', '#FF9F43', '#1DD1A1', '#54A0FF', '#5F27CD'];

    Color _fromHex(String hex) {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Form(
          key: _formKey,
          child: Wrap(
            runSpacing: 16,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(widget.title, style: theme.textTheme.titleLarge),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Habit name',
                  hintText: 'e.g. Read 10 pages',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a habit name'
                    : null,
              ),
              Row(
                children: [
                  Text('Times per day', style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _frequency > 1
                        ? () => setState(() => _frequency--)
                        : null,
                  ),
                  Text('$_frequency', style: theme.textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _frequency++),
                  ),
                ],
              ),
              Text('Color', style: theme.textTheme.bodyMedium),
              Row(
                children: [
                  for (final hex in colors)
                    GestureDetector(
                      onTap: () => setState(() => _selectedColorHex = hex),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8, top: 8),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _fromHex(hex),
                          border: Border.all(
                            color: _selectedColorHex == hex
                                ? theme.colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(widget.buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
