import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import 'couple_repository.dart';
import 'coupled_request_page.dart';
import 'love_pill_page.dart';
import 'shopping_hub_section.dart';
import 'tour_plan_section.dart';

class CoupledDashboardPage extends StatefulWidget {
  const CoupledDashboardPage({super.key});

  @override
  State<CoupledDashboardPage> createState() => _CoupledDashboardPageState();
}

class _CoupledDashboardPageState extends State<CoupledDashboardPage> {
  late final CoupleRepository _repo;

  bool _loading = true;
  DateTime? _relationshipDate;
  Timer? _timer;
  RealtimeChannel? _pillBadgeChannel;
  Duration _elapsed = Duration.zero;
  String? _coupleId;
  bool _decoupling = false;
  int _unreadPills = 0;

  late String _romanticMessage;
  final _messages = const [
    'Every second with you is my favourite moment.',
    'You are my today and all of my tomorrows.',
    'In a world of billions, my heart chose you.',
    'Your smile is the home my soul returns to.',
    'Our love story is my favourite notification.',
  ];

  @override
  void initState() {
    super.initState();
    _repo = CoupleRepository(Supabase.instance.client);
    _romanticMessage = _messages[Random().nextInt(_messages.length)];
    _loadRelationship();
  }

  Future<void> _loadRelationship() async {
    final couple = await _repo.fetchExistingCouple();

    if (!mounted) return;

    if (couple == null || couple['relationship_date'] == null) {
      setState(() {
        _loading = false;
        _relationshipDate = null;
      });
      return;
    }

    final dateStr = couple['relationship_date'] as String;
    final relDate = DateTime.tryParse(dateStr);

    setState(() {
      _relationshipDate = relDate;
      _coupleId = couple['id'] as String;
      _loading = false;
    });

    _startTimer();
    unawaited(_loadUnreadPills());
    _subscribeToUnreadPills(_coupleId!);
  }

  Future<void> _loadUnreadPills() async {
    final coupleId = _coupleId;
    if (coupleId == null) return;

    try {
      final count = await _repo.fetchUnreadLovePillCount(coupleId);
      if (mounted) setState(() => _unreadPills = count);
    } catch (_) {
      // Keep the dashboard usable if unread metadata is temporarily unavailable.
    }
  }

  void _subscribeToUnreadPills(String coupleId) {
    final existing = _pillBadgeChannel;
    if (existing != null) {
      unawaited(Supabase.instance.client.removeChannel(existing));
    }

    final channel = Supabase.instance.client.channel(
      'love-pill-badge-$coupleId',
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'couple_love_pills',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'couple_id',
        value: coupleId,
      ),
      callback: (_) => unawaited(_loadUnreadPills()),
    );
    channel.subscribe();
    _pillBadgeChannel = channel;
  }

  Future<void> _openLovePills() async {
    final coupleId = _coupleId;
    if (coupleId == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LovePillPage(coupleId: coupleId, repo: _repo),
      ),
    );
    if (mounted) unawaited(_loadUnreadPills());
  }

  void _startTimer() {
    _timer?.cancel();
    if (_relationshipDate == null) return;

    _updateElapsed();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateElapsed();
    });
  }

  void _updateElapsed() {
    if (!mounted || _relationshipDate == null) return;

    final now = DateTime.now();
    var diff = now.difference(_relationshipDate!);
    if (diff.isNegative) {
      diff = Duration.zero;
    }

    setState(() {
      _elapsed = diff;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    final channel = _pillBadgeChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  void _shuffleMessage() {
    setState(() {
      _romanticMessage = _messages[Random().nextInt(_messages.length)];
    });
  }

  Future<void> _confirmDecouple() async {
    final coupleId = _coupleId;
    if (coupleId == null || _decoupling) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = AppPalette.isDark(context);
        final accentColor = isDark
            ? const Color(0xFFFF8FB1)
            : Colors.pink.shade700;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF221729) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Row(
            children: [
              Icon(Icons.heart_broken_rounded, color: accentColor),
              const SizedBox(width: 10),
              const Expanded(child: Text('Decouple partner?')),
            ],
          ),
          content: const Text(
            'This will end the active couple connection. Your shared history will stay saved, but couple features will no longer be shared with this partner.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep together'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Decouple'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _decoupling = true);
    final error = await _repo.decouple(coupleId);

    if (!mounted) return;

    setState(() => _decoupling = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    _timer?.cancel();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('You are decoupled now.')));
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const CoupledRequestPage()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgImage = 'assets/coupled_images/couple-1.png';
    final counterImage = 'assets/coupled_images/couple-3.png';
    final isDark = AppPalette.isDark(context);
    final shellGradient = isDark
        ? const [Color(0xFF180E1A), Color(0xFF2A1533)]
        : const [Color(0xFFFFC1CC), Color(0xFFFFE4E1)];
    final cardColor = isDark
        ? const Color(0xFF221729)
        : Colors.white.withValues(alpha: 0.92);
    final borderColor = isDark
        ? const Color(0xFF6B466F)
        : Colors.pinkAccent.withValues(alpha: 0.5);
    final accentColor = isDark ? const Color(0xFFFF8FB1) : Colors.pink.shade700;
    final mutedText = isDark ? const Color(0xFFD8B9CB) : Colors.grey.shade700;
    final timeParts = _formatElapsed(_elapsed);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: accentColor,
        actions: [
          _LovePillAppBarButton(
            unreadCount: _unreadPills,
            accentColor: accentColor,
            backgroundColor: cardColor.withValues(alpha: 0.72),
            onPressed: _coupleId == null ? null : _openLovePills,
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton.filledTonal(
              tooltip: 'Decouple partner',
              onPressed: _coupleId == null || _decoupling
                  ? null
                  : _confirmDecouple,
              style: IconButton.styleFrom(
                backgroundColor: cardColor.withValues(alpha: 0.72),
                foregroundColor: accentColor,
              ),
              icon: _decoupling
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accentColor,
                      ),
                    )
                  : const Icon(Icons.heart_broken_rounded),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: shellGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.16,
                child: Image.asset(
                  bgImage,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight - 24,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: _shuffleMessage,
                                    child: Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        color: cardColor,
                                        boxShadow: [
                                          BoxShadow(
                                            blurRadius: 16,
                                            spreadRadius: 1,
                                            color: Colors.black.withValues(
                                              alpha: 0.18,
                                            ),
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.favorite_rounded,
                                            color: accentColor,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _romanticMessage,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Icon(
                                            Icons.auto_awesome_rounded,
                                            color: accentColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      color: cardColor,
                                      boxShadow: [
                                        BoxShadow(
                                          blurRadius: 18,
                                          spreadRadius: 2,
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          offset: const Offset(0, 12),
                                        ),
                                      ],
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Image.asset(
                                            counterImage,
                                            height: 80,
                                            width: 80,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Time together',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              if (_relationshipDate != null)
                                                Text(
                                                  'Since ${_relationshipDate!.toLocal().toString().split(' ').first}',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: mutedText,
                                                  ),
                                                )
                                              else
                                                Text(
                                                  'Anniversary date not set',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFFF9DA9,
                                                          )
                                                        : Colors.red.shade400,
                                                  ),
                                                ),
                                              const SizedBox(height: 12),
                                              _relationshipDate == null
                                                  ? const Text(
                                                      'Set your anniversary date to start the counter.',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    )
                                                  : _buildTimerRow(timeParts),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_coupleId != null) ...[
                                    const SizedBox(height: 20),
                                    ShoppingHubSection(
                                      coupleId: _coupleId!,
                                      repo: _repo,
                                    ),
                                    const SizedBox(height: 20),
                                    TourPlanSection(
                                      coupleId: _coupleId!,
                                      repo: _repo,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  _TimeParts _formatElapsed(Duration d) {
    final totalSeconds = d.inSeconds;
    final secondsInDay = 24 * 60 * 60;
    final days = totalSeconds ~/ secondsInDay;
    final remDay = totalSeconds % secondsInDay;
    final hours = remDay ~/ 3600;
    final remHour = remDay % 3600;
    final minutes = remHour ~/ 60;
    final seconds = remHour % 60;

    return _TimeParts(
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
  }

  Widget _buildTimerRow(_TimeParts t) {
    final isDark = AppTheme.themeMode.value == ThemeMode.dark;
    final accentColor = isDark ? const Color(0xFFFF8FB1) : Colors.pink.shade700;
    final labelStyle = TextStyle(
      fontSize: 12,
      color: isDark ? const Color(0xFFD8B9CB) : Colors.grey.shade700,
    );
    final valueStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : null,
    );

    String two(int n) => n.toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _timeBlock('${t.days}', 'days', valueStyle, labelStyle),
            _separator(),
            _timeBlock(two(t.hours), 'hours', valueStyle, labelStyle),
            _separator(),
            _timeBlock(two(t.minutes), 'minutes', valueStyle, labelStyle),
            _separator(),
            _timeBlock(two(t.seconds), 'seconds', valueStyle, labelStyle),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Counting every heartbeat together',
          style: TextStyle(fontSize: 12, color: accentColor),
        ),
      ],
    );
  }

  Widget _timeBlock(
    String value,
    String label,
    TextStyle valueStyle,
    TextStyle labelStyle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: valueStyle),
        Text(label, style: labelStyle),
      ],
    );
  }

  Widget _separator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _LovePillAppBarButton extends StatelessWidget {
  const _LovePillAppBarButton({
    required this.unreadCount,
    required this.accentColor,
    required this.backgroundColor,
    required this.onPressed,
  });

  final int unreadCount;
  final Color accentColor;
  final Color backgroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = unreadCount > 99 ? '99+' : '$unreadCount';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton.filledTonal(
          tooltip: 'Open Love Pills',
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: accentColor,
          ),
          icon: const Icon(Icons.medication_liquid_rounded),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 0,
            right: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE22D58),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimeParts {
  final int days;
  final int hours;
  final int minutes;
  final int seconds;

  _TimeParts({
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
  });
}
