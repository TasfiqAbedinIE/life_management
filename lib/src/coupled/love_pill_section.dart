import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/habit_notification_service.dart';
import '../theme/app_theme.dart';
import 'couple_repository.dart';

class LovePillSection extends StatefulWidget {
  final String coupleId;
  final CoupleRepository repo;

  const LovePillSection({
    super.key,
    required this.coupleId,
    required this.repo,
  });

  @override
  State<LovePillSection> createState() => _LovePillSectionState();
}

class _LovePillSectionState extends State<LovePillSection> {
  static const _templates = [
    _LovePillTemplate('Thinking of you', 'I paused for a second just to miss you.'),
    _LovePillTemplate('Tiny hug', 'Sending you a quiet little hug for your day.'),
    _LovePillTemplate('Proud of you', 'I see how hard you try, and I am proud of you.'),
    _LovePillTemplate('Come closer', 'Save me a little space beside you later.'),
    _LovePillTemplate('You matter', 'You make ordinary moments feel softer.'),
  ];

  final _customController = TextEditingController();
  final _random = Random();
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _sending = false;
  List<Map<String, dynamic>> _pills = const [];

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadPills();
    _subscribe();
  }

  @override
  void dispose() {
    _customController.dispose();
    final channel = _channel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _loadPills() async {
    setState(() => _loading = true);
    final pills = await widget.repo.fetchLovePills(widget.coupleId);
    if (!mounted) return;
    setState(() {
      _pills = pills;
      _loading = false;
    });
  }

  void _subscribe() {
    final channel = Supabase.instance.client.channel('couple-love-pills-${widget.coupleId}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'couple_love_pills',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'couple_id',
        value: widget.coupleId,
      ),
      callback: (payload) {
        final record = Map<String, dynamic>.from(payload.newRecord);
        _handleIncomingPill(record);
      },
    );
    channel.subscribe();
    _channel = channel;
  }

  Future<void> _handleIncomingPill(Map<String, dynamic> pill) async {
    if (!mounted) return;

    setState(() {
      final exists = _pills.any((existing) => existing['id'] == pill['id']);
      if (!exists) {
        _pills = [pill, ..._pills].take(40).toList();
      }
    });

    if (pill['sender_id'] == _currentUserId) return;

    final allowed = (await HabitNotificationService.areNotificationsAllowed()) ||
        (await HabitNotificationService.requestPermission());
    if (!allowed) return;

    await HabitNotificationService.showCouplePillNotification(
      title: 'New love pill',
      message: pill['message']?.toString() ?? 'Open Coupled to read it.',
    );
  }

  Future<void> _sendTemplate(_LovePillTemplate template) {
    return _sendPill(template.message, template.label);
  }

  Future<void> _sendCustom() async {
    await _sendPill(_customController.text, 'custom');
    if (mounted) {
      _customController.clear();
    }
  }

  Future<void> _sendSurprise() {
    final template = _templates[_random.nextInt(_templates.length)];
    return _sendPill(template.message, 'surprise');
  }

  Future<void> _sendPill(String message, String pillType) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final pill = await widget.repo.sendLovePill(
        coupleId: widget.coupleId,
        message: trimmed,
        pillType: pillType,
      );
      if (!mounted) return;
      if (pill != null) {
        setState(() {
          final exists = _pills.any((existing) => existing['id'] == pill['id']);
          if (!exists) {
            _pills = [pill, ..._pills].take(40).toList();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send love pill: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);
    final accent = isDark ? const Color(0xFFFF8FB1) : Colors.pink.shade700;
    final muted = isDark ? const Color(0xFFD8B9CB) : Colors.grey.shade700;
    final surface = isDark
        ? const Color(0xFF221729)
        : Colors.white.withValues(alpha: 0.94);
    final softSurface = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.72);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: surface,
        border: Border.all(
          color: isDark ? const Color(0xFF6B466F) : Colors.pinkAccent.withValues(alpha: 0.38),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 1,
            color: Colors.black.withValues(alpha: 0.14),
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.local_pharmacy_outlined, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Love Pills',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Send tiny messages that land live for your better half.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loadPills,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _templates.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ActionChip(
                    avatar: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Surprise me'),
                    onPressed: _sending ? null : _sendSurprise,
                  );
                }

                final template = _templates[index - 1];
                return ActionChip(
                  label: Text(template.label),
                  onPressed: _sending ? null : () => _sendTemplate(template),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Write your own pill',
                    counterText: '',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 48,
                height: 48,
                child: FilledButton(
                  onPressed: _sending ? null : _sendCustom,
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Pill history',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_pills.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: softSurface,
              ),
              child: Text(
                'No pills yet. Send the first tiny dose of affection.',
                style: TextStyle(color: muted, height: 1.35),
              ),
            )
          else
            Column(
              children: _pills.take(8).toList().reversed.map((pill) {
                final isMine = pill['sender_id'] == _currentUserId;
                return _PillBubble(
                  pill: pill,
                  isMine: isMine,
                  accent: accent,
                  muted: muted,
                  softSurface: softSurface,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _PillBubble extends StatelessWidget {
  final Map<String, dynamic> pill;
  final bool isMine;
  final Color accent;
  final Color muted;
  final Color softSurface;

  const _PillBubble({
    required this.pill,
    required this.isMine,
    required this.accent,
    required this.muted,
    required this.softSurface,
  });

  @override
  Widget build(BuildContext context) {
    final message = pill['message']?.toString() ?? '';
    final createdAt = DateTime.tryParse(pill['created_at']?.toString() ?? '');
    final timeLabel = createdAt == null
        ? ''
        : '${createdAt.toLocal().hour.toString().padLeft(2, '0')}:'
            '${createdAt.toLocal().minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: isMine ? accent.withValues(alpha: 0.16) : softSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 18),
          ),
          border: Border.all(color: accent.withValues(alpha: isMine ? 0.28 : 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (timeLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                isMine ? 'You sent it at $timeLabel' : 'Received at $timeLabel',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 11,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LovePillTemplate {
  final String label;
  final String message;

  const _LovePillTemplate(this.label, this.message);
}
