import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EpubReaderPage extends StatefulWidget {
  const EpubReaderPage({
    super.key,
    required this.title,
    required this.sourceUrl,
    required this.localFilePath,
    required this.initialProgress,
    required this.onProgressChanged,
    this.resumeKey,
  }) : assert(
         (sourceUrl != null && sourceUrl != '') || localFilePath != null,
         'Either sourceUrl or localFilePath is required.',
       );

  final String title;
  final String? sourceUrl;
  final String? localFilePath;
  final double initialProgress;
  final ValueChanged<double> onProgressChanged;
  final String? resumeKey;

  @override
  State<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends State<EpubReaderPage> {
  final _controller = EpubController();

  double _currentProgress = 0.0;
  bool _showHud = true;
  double _fontSize = 18;
  EpubThemeType _theme = EpubThemeType.custom;
  _SelectionState? _selection;

  bool _resumeReady = false;
  String? _resumeCfi;
  Timer? _resumeSaveTimer;
  Offset? _touchDownPoint;

  String get _resumeCfiKey =>
      'epub_resume_cfi_${widget.resumeKey ?? widget.title}';
  String get _resumeProgressKey =>
      'epub_resume_progress_${widget.resumeKey ?? widget.title}';

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.initialProgress.clamp(0.0, 1.0).toDouble();
    _restoreResumeState();
  }

  @override
  void dispose() {
    _resumeSaveTimer?.cancel();
    unawaited(_persistResumeState());
    widget.onProgressChanged(_currentProgress);
    super.dispose();
  }

  Future<void> _restoreResumeState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCfi = prefs.getString(_resumeCfiKey);
    final savedProgress = prefs.getDouble(_resumeProgressKey);
    final effectiveProgress = [
      widget.initialProgress,
      savedProgress ?? 0.0,
    ].reduce((a, b) => a > b ? a : b).clamp(0.0, 1.0).toDouble();

    if (!mounted) return;
    setState(() {
      _resumeCfi = savedCfi;
      _currentProgress = effectiveProgress;
      _resumeReady = true;
    });
  }

  Future<void> _persistResumeState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_resumeProgressKey, _currentProgress);
    if (_resumeCfi != null && _resumeCfi!.isNotEmpty) {
      await prefs.setString(_resumeCfiKey, _resumeCfi!);
    }
  }

  void _scheduleResumeSave() {
    _resumeSaveTimer?.cancel();
    _resumeSaveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persistResumeState());
    });
  }

  void _toggleHud() {
    if (!mounted) return;
    setState(() => _showHud = !_showHud);
  }

  void _handleViewerTouchDown(double x, double y) {
    _touchDownPoint = Offset(x, y);
  }

  void _handleViewerTouchUp(double x, double y) {
    final start = _touchDownPoint;
    _touchDownPoint = null;
    if (_selection != null || start == null) return;

    final delta = (start - Offset(x, y)).distance;
    final inBottomTapZone = start.dy >= 0.70 && y >= 0.70;
    final looksLikeTap = delta <= 0.035;

    if (looksLikeTap && inBottomTapZone) {
      _toggleHud();
    }
  }

  void _cycleTheme() {
    switch (_theme) {
      case EpubThemeType.custom:
        _theme = EpubThemeType.light;
      case EpubThemeType.light:
        _theme = EpubThemeType.dark;
      case EpubThemeType.dark:
        _theme = EpubThemeType.custom;
    }

    _controller.updateTheme(theme: _readerThemeFor(_theme));
    setState(() {});
  }

  EpubTheme _readerThemeFor(EpubThemeType theme) {
    switch (theme) {
      case EpubThemeType.light:
        return EpubTheme.custom(
          backgroundDecoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
          foregroundColor: const Color(0xFF111827),
          customCss: _readerCss(
            textColor: '#111827',
            backgroundColor: '#FFFFFF',
            linkColor: '#1D4ED8',
          ),
        );
      case EpubThemeType.dark:
        return EpubTheme.custom(
          backgroundDecoration: const BoxDecoration(color: Color(0xFF0F172A)),
          foregroundColor: const Color(0xFFF8FAFC),
          customCss: _readerCss(
            textColor: '#F8FAFC',
            backgroundColor: '#0F172A',
            linkColor: '#93C5FD',
          ),
        );
      case EpubThemeType.custom:
        return EpubTheme.custom(
          backgroundDecoration: const BoxDecoration(color: Color(0xFFF6E8C3)),
          foregroundColor: const Color(0xFF4B3520),
          customCss: _readerCss(
            textColor: '#4B3520',
            backgroundColor: '#F6E8C3',
            linkColor: '#7C4A03',
          ),
        );
    }
  }

  Map<String, Map<String, String>> _readerCss({
    required String textColor,
    required String backgroundColor,
    required String linkColor,
  }) {
    final baseText = {
      'color': '$textColor !important',
      'font-size': '${_fontSize}px',
      'line-height': '1.7',
    };

    return {
      'html': {
        'background-color': '$backgroundColor !important',
      },
      'body': {
        'font-family': 'Georgia, serif',
        'padding': '8px 10px',
        'background-color': '$backgroundColor !important',
        'color': '$textColor !important',
        'line-height': '1.7',
      },
      'p': baseText,
      'div': {'color': '$textColor !important'},
      'span': {'color': '$textColor !important'},
      'li': baseText,
      'blockquote': {'color': '$textColor !important'},
      'h1': {'color': '$textColor !important'},
      'h2': {'color': '$textColor !important'},
      'h3': {'color': '$textColor !important'},
      'h4': {'color': '$textColor !important'},
      'h5': {'color': '$textColor !important'},
      'h6': {'color': '$textColor !important'},
      'a': {
        'color': '$linkColor !important',
        '-webkit-text-fill-color': '$linkColor !important',
      },
      'a:link': {
        'color': '$linkColor !important',
        '-webkit-text-fill-color': '$linkColor !important',
      },
      'a:visited': {
        'color': '$linkColor !important',
        '-webkit-text-fill-color': '$linkColor !important',
      },
    };
  }

  Future<void> _applyMark(Color color) async {
    final selection = _selection;
    if (selection == null || selection.selectionCfi.isEmpty) return;
    _controller.addHighlight(
      cfi: selection.selectionCfi,
      color: color,
      opacity: 0.32,
    );
    if (!mounted) return;
    setState(() => _selection = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Highlight added.')),
    );
  }

  Future<void> _applyUnderline() async {
    final selection = _selection;
    if (selection == null || selection.selectionCfi.isEmpty) return;
    _controller.addUnderline(cfi: selection.selectionCfi);
    if (!mounted) return;
    setState(() => _selection = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Underline added.')),
    );
  }

  Future<void> _changeFontSize(double delta) async {
    final next = (_fontSize + delta).clamp(14.0, 30.0).toDouble();
    setState(() => _fontSize = next);
    await _controller.setFontSize(fontSize: _fontSize);
    _controller.updateTheme(theme: _readerThemeFor(_theme));
  }

  @override
  Widget build(BuildContext context) {
    if (!_resumeReady) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Toggle theme',
              onPressed: _cycleTheme,
              icon: const Icon(Icons.palette_outlined),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final source = widget.localFilePath != null
        ? EpubSource.fromFile(File(widget.localFilePath!))
        : EpubSource.fromUrl(widget.sourceUrl!);

    final accent = switch (_theme) {
      EpubThemeType.dark => const Color(0xFF93C5FD),
      EpubThemeType.light => const Color(0xFF2563EB),
      EpubThemeType.custom => const Color(0xFFD97706),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: _cycleTheme,
            icon: const Icon(Icons.palette_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          EpubViewer(
            epubController: _controller,
            epubSource: source,
            initialCfi: _resumeCfi,
            displaySettings: EpubDisplaySettings(
              fontSize: _fontSize.toInt(),
              theme: _readerThemeFor(_theme),
            ),
            onTouchDown: _handleViewerTouchDown,
            onTouchUp: _handleViewerTouchUp,
            onRelocated: (location) {
              setState(() {
                _currentProgress = location.progress.clamp(0.0, 1.0).toDouble();
                _resumeCfi = location.startCfi;
              });
              _scheduleResumeSave();
            },
            onTextSelected: (selection) {
              setState(() {
                _selection = _SelectionState(
                  selectedText: selection.selectedText,
                  selectionCfi: selection.selectionCfi,
                );
              });
            },
            onDeselection: () {
              if (!mounted) return;
              setState(() => _selection = null);
            },
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 14,
            right: 14,
            bottom: _showHud ? 16 : -280,
            child: IgnorePointer(
              ignoring: !_showHud,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            color: accent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _currentProgress,
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(999),
                              color: accent,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(_currentProgress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _miniIcon(
                            icon: Icons.visibility_off_rounded,
                            onTap: _toggleHud,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: accent,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: accent,
                        ),
                        child: Slider(
                          value: _currentProgress,
                          onChanged: (v) => setState(() => _currentProgress = v),
                          onChangeEnd: (v) {
                            _controller.toProgressPercentage(v);
                            _scheduleResumeSave();
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _miniIcon(
                            icon: Icons.text_decrease_rounded,
                            onTap: () => _changeFontSize(-1),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _fontSize.toStringAsFixed(0),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _miniIcon(
                            icon: Icons.text_increase_rounded,
                            onTap: () => _changeFontSize(1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: 14,
            right: 14,
            bottom: _selection == null ? -160 : (_showHud ? 132 : 20),
            child: _selectionActionBar(accent),
          ),
        ],
      ),
    );
  }

  Widget _selectionActionBar(Color accent) {
    final selection = _selection;
    if (selection == null) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selection.selectedText.trim().replaceAll('\n', ' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _markChip(
                  label: 'Amber',
                  color: const Color(0xFFF59E0B),
                  onTap: () => _applyMark(const Color(0xFFF59E0B)),
                ),
                _markChip(
                  label: 'Mint',
                  color: const Color(0xFF10B981),
                  onTap: () => _applyMark(const Color(0xFF10B981)),
                ),
                _markChip(
                  label: 'Sky',
                  color: const Color(0xFF38BDF8),
                  onTap: () => _applyMark(const Color(0xFF38BDF8)),
                ),
                _markChip(
                  label: 'Underline',
                  color: accent,
                  onTap: _applyUnderline,
                ),
                _markChip(
                  label: 'Dismiss',
                  color: Colors.white70,
                  onTap: () => setState(() => _selection = null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniIcon({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _markChip({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SelectionState {
  const _SelectionState({
    required this.selectedText,
    required this.selectionCfi,
  });

  final String selectedText;
  final String selectionCfi;
}

