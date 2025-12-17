// lib/features/habits/presentation/widgets/habit_card.dart
import 'package:flutter/material.dart';
import '../../models/habit.dart';
import '../../models/habit_entry.dart';

class HabitCard extends StatefulWidget {
  final Habit habit;
  final List<HabitEntry> entries;
  final bool isExpanded;

  // partial progress actions
  final VoidCallback onIncrementToday;
  final VoidCallback onDecrementToday;

  // expand
  final VoidCallback onToggleExpand;

  // swipe actions
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HabitCard({
    super.key,
    required this.habit,
    required this.entries,
    required this.isExpanded,
    required this.onIncrementToday,
    required this.onDecrementToday,
    required this.onToggleExpand,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    if (widget.isExpanded) _fadeCtrl.value = 1;
  }

  @override
  void didUpdateWidget(covariant HabitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _fadeCtrl.forward();
      } else {
        _fadeCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Color _parseColor(String? hex, BuildContext context) {
    if (hex == null) return Theme.of(context).colorScheme.primary;
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  int _todayCount() {
    final t = DateTime.now();
    final today = DateTime(t.year, t.month, t.day);

    for (final e in widget.entries) {
      final d = DateTime(e.entryDate.year, e.entryDate.month, e.entryDate.day);
      if (d == today) return e.doneCount;
    }
    return 0;
  }

  /// streak based on "full completion" days (done_count >= frequency)
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

    for (final e in widget.entries) {
      final d = DateTime(e.entryDate.year, e.entryDate.month, e.entryDate.day);
      if (dateMap.containsKey(d)) {
        dateMap[d] = e.doneCount >= widget.habit.frequencyPerDay;
      }
    }

    int current = 0;
    int best = 0;

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

  Color _heatColor(Color base, int done, int target) {
    if (target <= 0) return base.withOpacity(0.10);

    final ratio = (done / target).clamp(0.0, 1.0);
    // 0% => 0.10, 100% => 0.95
    final opacity = 0.10 + (0.85 * ratio);
    return base.withOpacity(opacity);
  }

  Widget _buildHeatmap(BuildContext context, Color primary) {
    final now = DateTime.now();
    final size = 14.0;
    final gap = 4.0;

    // last 30 dates in order old->new
    final dates = <DateTime>[];
    for (int i = 29; i >= 0; i--) {
      dates.add(
        DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
      );
    }

    // map date->doneCount
    final doneMap = <DateTime, int>{};
    for (final e in widget.entries) {
      final d = DateTime(e.entryDate.year, e.entryDate.month, e.entryDate.day);
      doneMap[d] = e.doneCount;
    }

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: dates.map((d) {
        final done = doneMap[d] ?? 0;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: _heatColor(primary, done, widget.habit.frequencyPerDay),
          ),
        );
      }).toList(),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete habit?'),
        content: const Text('This will delete the habit and its history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = _parseColor(widget.habit.colorHex, context);

    final todayCount = _todayCount();
    final freq = widget.habit.frequencyPerDay;
    final isFullDone = todayCount >= freq;

    final (currentStreak, bestStreak) = _computeStreaks();

    // Dismissible supports swipe actions.
    // - Swipe right (startToEnd) => EDIT (do not dismiss)
    // - Swipe left (endToStart) => DELETE (confirm then dismiss)
    return Dismissible(
      key: ValueKey('habit-${widget.habit.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // EDIT swipe
          widget.onEdit();
          return false; // don't remove from list
        } else {
          // DELETE swipe
          final ok = await _confirmDelete(context);
          if (ok) widget.onDelete();
          return ok;
        }
      },
      background: _SwipeBg(
        icon: Icons.edit_rounded,
        label: 'Edit',
        color: primary.withOpacity(0.15),
        alignLeft: true,
      ),
      secondaryBackground: _SwipeBg(
        icon: Icons.delete_rounded,
        label: 'Delete',
        color: Colors.red.withOpacity(0.15),
        alignLeft: false,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
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
          border: Border.all(color: primary.withOpacity(0.10)),
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
            // Top row: name + freq + partial control + expand arrow
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: name + frequency
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.habit.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Target: $freq / day',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.72,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right: partial progress control
                _MiniIconBtn(
                  icon: Icons.remove_rounded,
                  onTap: todayCount > 0 ? widget.onDecrementToday : null,
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: primary.withOpacity(isFullDone ? 0.18 : 0.10),
                    border: Border.all(color: primary.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isFullDone
                            ? Icons.check_circle_rounded
                            : Icons.timelapse_rounded,
                        size: 16,
                        color: isFullDone ? primary : theme.iconTheme.color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$todayCount/$freq',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                _MiniIconBtn(
                  icon: Icons.add_rounded,
                  onTap: todayCount < freq ? widget.onIncrementToday : null,
                ),

                IconButton(
                  onPressed: widget.onToggleExpand,
                  icon: AnimatedRotation(
                    turns: widget.isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
              ],
            ),

            // Expanded content (smooth)
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              child: widget.isExpanded
                  ? FadeTransition(
                      opacity: _fade,
                      child: Padding(
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
                                color: theme.textTheme.bodySmall?.color
                                    ?.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _buildHeatmap(context, primary),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _MiniIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      color: onTap == null ? theme.disabledColor : theme.iconTheme.color,
      splashRadius: 18,
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool alignLeft;

  const _SwipeBg({
    required this.icon,
    required this.label,
    required this.color,
    required this.alignLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignLeft) ...[
            Icon(icon),
            const SizedBox(width: 8),
            Text(label),
          ] else ...[
            Text(label),
            const SizedBox(width: 8),
            Icon(icon),
          ],
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
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
