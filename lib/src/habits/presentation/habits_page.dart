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
      setState(() {
        _habits = habits;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onToggleToday(Habit habit) async {
    await _repo.toggleToday(habit: habit);
    // For a simple UI, just reload entries for that habit if expanded
    if (_expandedHabits.contains(habit.id)) {
      final entries = await _repo.fetchEntriesForHabit(habitId: habit.id);
      setState(() {
        _entries[habit.id] = entries;
      });
    } else {
      setState(() {}); // trigger rebuild for button color state via future
    }
  }

  Future<void> _onExpand(Habit habit) async {
    if (_expandedHabits.contains(habit.id)) {
      setState(() {
        _expandedHabits.remove(habit.id);
      });
      return;
    }

    _expandedHabits.add(habit.id);
    setState(() {}); // immediate expand (can show loading shimmer if you want)

    final entries = await _repo.fetchEntriesForHabit(habitId: habit.id);
    setState(() {
      _entries[habit.id] = entries;
    });
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
                    onToggleToday: () => _onToggleToday(habit),
                    onToggleExpand: () => _onExpand(habit),
                  );
                },
              ),
      ),
    );
  }
}

class _AddHabitSheet extends StatefulWidget {
  const _AddHabitSheet();

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  int _frequency = 1;
  String? _selectedColorHex;

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
              Text('New Habit', style: theme.textTheme.titleLarge),
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
                  child: const Text('Save habit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
