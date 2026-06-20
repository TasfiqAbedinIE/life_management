import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'couple_repository.dart';

class LovePillPage extends StatefulWidget {
  const LovePillPage({super.key, required this.coupleId, required this.repo});

  final String coupleId;
  final CoupleRepository repo;

  @override
  State<LovePillPage> createState() => _LovePillPageState();
}

class _LovePillPageState extends State<LovePillPage> {
  static const _templates = [
    _PillTemplate('Thinking of you', 'I paused for a second just to miss you.'),
    _PillTemplate('Tiny hug', 'Sending you a quiet little hug for your day.'),
    _PillTemplate(
      'Proud of you',
      'I see how hard you try, and I am proud of you.',
    ),
    _PillTemplate('Come closer', 'Save me a little space beside you later.'),
    _PillTemplate('You matter', 'You make ordinary moments feel softer.'),
  ];

  static const _backgrounds = [
    _PillBackground(
      keyName: 'blush',
      label: 'Blush garden',
      lightColors: [Color(0xFFFFF8F6), Color(0xFFF9D5DE), Color(0xFFEFA8BD)],
      darkColors: [Color(0xFF1D1218), Color(0xFF3B1D2A), Color(0xFF6D2944)],
      lightAccent: Color(0xFFA9345D),
      darkAccent: Color(0xFFFF91B5),
    ),
    _PillBackground(
      keyName: 'sunset',
      label: 'Golden hour',
      lightColors: [Color(0xFFFFF2DD), Color(0xFFF7B6A8), Color(0xFFBE6B7B)],
      darkColors: [Color(0xFF201410), Color(0xFF4B2421), Color(0xFF773A48)],
      lightAccent: Color(0xFF8D324D),
      darkAccent: Color(0xFFFFAA91),
    ),
    _PillBackground(
      keyName: 'midnight',
      label: 'Midnight rose',
      lightColors: [Color(0xFFF7EFF8), Color(0xFFDCC2DE), Color(0xFFB87599)],
      darkColors: [Color(0xFF160F20), Color(0xFF3B193B), Color(0xFF7B2E55)],
      lightAccent: Color(0xFF71304F),
      darkAccent: Color(0xFFFF9BBC),
    ),
  ];

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  RealtimeChannel? _channel;
  List<Map<String, dynamic>> _pills = const [];
  String _backgroundKey = 'blush';
  bool _loading = true;
  bool _sending = false;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  _PillBackground get _background => _backgrounds.firstWhere(
    (background) => background.keyName == _backgroundKey,
    orElse: () => _backgrounds.first,
  );

  @override
  void initState() {
    super.initState();
    _loadConversation();
    _subscribe();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    final channel = _channel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  Future<void> _loadConversation() async {
    if (mounted) setState(() => _loading = true);

    try {
      final background = await widget.repo.fetchLovePillBackground(
        widget.coupleId,
      );
      await widget.repo.markReceivedLovePillsRead(widget.coupleId);
      final pills = await widget.repo.fetchLovePills(widget.coupleId);

      if (!mounted) return;
      setState(() {
        _backgroundKey = background;
        _pills = pills;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load love pills: $error')),
      );
    }
  }

  void _subscribe() {
    final channel = Supabase.instance.client.channel(
      'love-pill-chat-${widget.coupleId}',
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'couple_love_pills',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'couple_id',
        value: widget.coupleId,
      ),
      callback: (payload) {
        final record = Map<String, dynamic>.from(payload.newRecord);
        if (record.isEmpty || !mounted) return;

        setState(() {
          final index = _pills.indexWhere((pill) => pill['id'] == record['id']);
          if (index == -1) {
            _pills = [record, ..._pills].take(100).toList();
          } else {
            final updated = [..._pills];
            updated[index] = record;
            _pills = updated;
          }
        });

        if (record['sender_id'] != _currentUserId &&
            record['read_at'] == null) {
          unawaited(widget.repo.markReceivedLovePillsRead(widget.coupleId));
        }
      },
    );

    channel.subscribe();
    _channel = channel;
  }

  Future<void> _sendPill(String message, String type) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final pill = await widget.repo.sendLovePill(
        coupleId: widget.coupleId,
        message: trimmed,
        pillType: type,
      );
      if (!mounted) return;

      if (pill != null && !_pills.any((item) => item['id'] == pill['id'])) {
        setState(() => _pills = [pill, ..._pills].take(100).toList());
      }
      _messageController.clear();
      _scrollToLatest();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send this pill: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _chooseBackground() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _BackgroundPicker(
        backgrounds: _backgrounds,
        selectedKey: _backgroundKey,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );

    if (selected == null || selected == _backgroundKey || !mounted) return;

    setState(() => _backgroundKey = selected);
    try {
      await widget.repo.saveLovePillBackground(
        coupleId: widget.coupleId,
        backgroundKey: selected,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save this background: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final background = _background;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = background.colorsFor(isDark);
    final accent = background.accentFor(isDark);
    final foreground = isDark ? Colors.white : const Color(0xFF3E2430);
    final muted = foreground.withValues(alpha: 0.68);

    return Scaffold(
      backgroundColor: colors.first,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: foreground,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Love Pills',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              'A private little place for two',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Change conversation background',
            onPressed: _chooseBackground,
            icon: const Icon(Icons.wallpaper_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: 105,
              right: -28,
              child: _SoftHeart(size: 150, opacity: 0.08),
            ),
            const Positioned(
              bottom: 170,
              left: -36,
              child: _SoftHeart(size: 120, opacity: 0.07),
            ),
            SafeArea(
              child: Column(
                children: [
                  _TemplateRibbon(
                    templates: _templates,
                    accent: accent,
                    foreground: foreground,
                    sending: _sending,
                    onSelected: (template) =>
                        _sendPill(template.message, template.label),
                  ),
                  Expanded(
                    child: _loading
                        ? Center(
                            child: CircularProgressIndicator(color: accent),
                          )
                        : _pills.isEmpty
                        ? _EmptyConversation(
                            foreground: foreground,
                            accent: accent,
                          )
                        : ListView.builder(
                            reverse: true,
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                            itemCount: _pills.length,
                            itemBuilder: (context, index) {
                              final pill = _pills[index];
                              return _ChatBubble(
                                pill: pill,
                                isMine: pill['sender_id'] == _currentUserId,
                                accent: accent,
                                foreground: foreground,
                                darkBackground: isDark,
                              );
                            },
                          ),
                  ),
                  _Composer(
                    controller: _messageController,
                    sending: _sending,
                    accent: accent,
                    darkBackground: isDark,
                    onSend: () => _sendPill(_messageController.text, 'custom'),
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

class _TemplateRibbon extends StatelessWidget {
  const _TemplateRibbon({
    required this.templates,
    required this.accent,
    required this.foreground,
    required this.sending,
    required this.onSelected,
  });

  final List<_PillTemplate> templates;
  final Color accent;
  final Color foreground;
  final bool sending;
  final ValueChanged<_PillTemplate> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: templates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final template = templates[index];
          return ActionChip(
            avatar: Icon(Icons.favorite_rounded, size: 15, color: accent),
            label: Text(template.label),
            labelStyle: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            side: BorderSide(color: accent.withValues(alpha: 0.28)),
            onPressed: sending ? null : () => onSelected(template),
          );
        },
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.pill,
    required this.isMine,
    required this.accent,
    required this.foreground,
    required this.darkBackground,
  });

  final Map<String, dynamic> pill;
  final bool isMine;
  final Color accent;
  final Color foreground;
  final bool darkBackground;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(pill['created_at']?.toString() ?? '');
    final time = createdAt == null
        ? ''
        : DateFormat('MMM d, h:mm a').format(createdAt.toLocal());
    final isRead = pill['read_at'] != null;
    final bubbleColor = isMine
        ? accent.withValues(alpha: darkBackground ? 0.82 : 0.92)
        : Colors.white.withValues(alpha: darkBackground ? 0.13 : 0.78);
    final textColor = isMine ? Colors.white : foreground;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 9),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isMine ? 22 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 22),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: darkBackground ? 0.12 : 0.42),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pill['message']?.toString() ?? '',
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                height: 1.32,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.68),
                      fontSize: 10,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 5),
                    Icon(
                      isRead ? Icons.done_all_rounded : Icons.check_rounded,
                      size: 14,
                      color: isRead
                          ? const Color(0xFFB7F4FF)
                          : textColor.withValues(alpha: 0.72),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.accent,
    required this.darkBackground,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final Color accent;
  final bool darkBackground;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: (darkBackground ? const Color(0xFF170F20) : Colors.white)
            .withValues(alpha: 0.82),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 180,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Write a tiny dose of love...',
                counterText: '',
                filled: true,
                fillColor: darkBackground
                    ? Colors.white.withValues(alpha: 0.09)
                    : const Color(0xFFFFF7F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 50,
            height: 50,
            child: FilledButton(
              onPressed: sending ? null : onSend,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
              child: sending
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.favorite_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.foreground, required this.accent});

  final Color foreground;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded, color: accent, size: 54),
            const SizedBox(height: 15),
            Text(
              'Your little love story starts here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a pill above or write something only your better half should hear.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foreground.withValues(alpha: 0.68),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundPicker extends StatelessWidget {
  const _BackgroundPicker({
    required this.backgrounds,
    required this.selectedKey,
    required this.isDark,
  });

  final List<_PillBackground> backgrounds;
  final String selectedKey;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set the mood',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Row(
              children: backgrounds.map((background) {
                final selected = background.keyName == selectedKey;
                final colors = background.colorsFor(isDark);
                final accent = background.accentFor(isDark);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(background.keyName),
                    child: Container(
                      height: 122,
                      margin: EdgeInsets.only(
                        right: background == backgrounds.last ? 0 : 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? accent : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Icon(
                              Icons.favorite_rounded,
                              color: accent,
                              size: 32,
                            ),
                          ),
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: Text(
                              background.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF4D2635),
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftHeart extends StatelessWidget {
  const _SoftHeart({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.favorite_rounded,
      size: size,
      color: Colors.white.withValues(alpha: opacity),
    );
  }
}

class _PillTemplate {
  const _PillTemplate(this.label, this.message);

  final String label;
  final String message;
}

class _PillBackground {
  const _PillBackground({
    required this.keyName,
    required this.label,
    required this.lightColors,
    required this.darkColors,
    required this.lightAccent,
    required this.darkAccent,
  });

  final String keyName;
  final String label;
  final List<Color> lightColors;
  final List<Color> darkColors;
  final Color lightAccent;
  final Color darkAccent;

  List<Color> colorsFor(bool isDark) => isDark ? darkColors : lightColors;

  Color accentFor(bool isDark) => isDark ? darkAccent : lightAccent;
}
