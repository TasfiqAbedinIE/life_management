// lib/features/habits/presentation/widgets/habit_card.dart
import 'package:flutter/material.dart';
import '../../models/habit.dart';
import '../../models/habit_entry.dart';

class HabitCard extends StatelessWidget {
  final Habit habit;
  final List<HabitEntry> entries;
  final bool isExpanded;
  final VoidCallback onToggleToday;
  final VoidCallback onToggleExpand;

  const HabitCard({
    super.key,
    required this.habit,
    required this.entries,
    required this.isExpanded,
    required this.onToggleToday,
    required this.onToggleExpand,
  });

  Color _parseColor(String? hex, BuildContext context) {
    if (hex == null) return Theme.of(context).colorScheme.primary;
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  bool _isTodayDone() {
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);
    final entry = entries.firstWhere(
      (e) =>
          e.entryDate.year == dateOnly.year &&
          e.entryDate.month == dateOnly.month &&
          e.entryDate.day == dateOnly.day,
      orElse: () => HabitEntry(
        id: '',
        habitId: habit.id,
        entryDate: dateOnly,
        doneCount: 0,
        createdAt: DateTime.now(),
      ),
    );
    return entry.doneCount >= habit.frequencyPerDay;
  }

  /// Compute current streak and best streak in last 30 days
  (int current, int best) _computeStreaks() {
    final now = DateTime.now();
    final dateMap = <DateTime, bool>{};

    for (int i = 0; i < 30; i++) {
      final d = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      dateMap[d] = false;
    }

    for (final e in entries) {
      final d = DateTime(e.entryDate.year, e.entryDate.month, e.entryDate.day);
      if (dateMap.containsKey(d)) {
        dateMap[d] = e.doneCount >= habit.frequencyPerDay;
      }
    }

    int current = 0;
    int best = 0;

    // current streak: go backward from today
    for (int i = 0; i < 30; i++) {
      final d = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      if (dateMap[d] == true) {
        current++;
      } else {
        break;
      }
    }

    // best streak in last 30 days
    int temp = 0;
    for (int i = 0; i < 30; i++) {
      final d = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      if (dateMap[d] == true) {
        temp++;
        if (temp > best) best = temp;
      } else {
        temp = 0;
      }
    }

    return (current, best);
  }

  Widget _buildHeatmap(BuildContext context) {
    final now = DateTime.now();
    final size = 14.0;
    final gap = 4.0;

    // Build map for 30 days
    final dateStatus = <DateTime, bool>{};
    for (int i = 29; i >= 0; i--) {
      final d = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      dateStatus[d] = false;
    }
    for (final e in entries) {
      final d = DateTime(e.entryDate.year, e.entryDate.month, e.entryDate.day);
      if (dateStatus.containsKey(d)) {
        dateStatus[d] = e.doneCount >= habit.frequencyPerDay;
      }
    }

    final primary = _parseColor(habit.colorHex, context);

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: dateStatus.entries.map((entry) {
        final isDone = entry.value;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isDone
                ? primary.withOpacity(0.9)
                : primary.withOpacity(0.12),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = _parseColor(habit.colorHex, context);
    final doneToday = _isTodayDone();
    final (currentStreak, bestStreak) = _computeStreaks();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surfaceVariant.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row: name + frequency + today button + expand arrow
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: name + frequency
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Per day: ${habit.frequencyPerDay} times',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right: today complete button
              GestureDetector(
                onTap: onToggleToday,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: doneToday ? primary : Colors.transparent,
                    border: Border.all(
                      color: doneToday ? primary : theme.dividerColor,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        doneToday
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: doneToday ? Colors.white : theme.iconTheme.color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        doneToday ? 'Done' : 'Mark done',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: doneToday ? Colors.white : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleExpand,
                icon: AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
            ],
          ),

          // Expanded content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatChip(
                        label: 'Current streak',
                        value: '$currentStreak days',
                        color: primary,
                      ),
                      const SizedBox(width: 8),
                      _StatChip(
                        label: 'Best streak',
                        value: '$bestStreak days',
                        color: primary.withOpacity(0.85),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Last 30 days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildHeatmap(context),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color.withOpacity(0.08),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.textTheme.labelSmall?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
