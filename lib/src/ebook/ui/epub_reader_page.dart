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
  String _hudFontFamily = 'Outfit';
  EpubThemeType _theme = EpubThemeType.custom;
  _SelectionState? _selection;

  bool _resumeReady = false;
  String? _resumeCfi;
  Timer? _resumeSaveTimer;

  String get _resumeCfiKey => 'epub_resume_cfi_${widget.resumeKey ?? widget.title}';
  String get _resumeProgressKey =>
      'epub_resume_progress_${widget.resumeKey ?? widget.title}';

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.initialProgress.clamp(0.0, 1.0).toDouble();
    _restoreResumeState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Theme.of(context).brightness == Brightness.dark &&
        _theme == EpubThemeType.custom) {
      _theme = EpubThemeType.dark;
      _controller.updateTheme(theme: EpubTheme.dark());
    }
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

    if (!mounted) return;
    setState(() {
      _resumeCfi = savedCfi;
      if (savedProgress != null && savedProgress > _currentProgress) {
        _currentProgress = savedProgress.clamp(0.0, 1.0).toDouble();
      }
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

  void _handleViewerTap(double x, double y) {
    final inMiddleBand = x >= 0.30 && x <= 0.70 && y >= 0.18 && y <= 0.82;
    if (inMiddleBand) {
      _toggleHud();
    }
  }

  void _cycleTheme() {
    switch (_theme) {
      case EpubThemeType.custom:
        _theme = EpubThemeType.light;
        _controller.updateTheme(theme: EpubTheme.light());
      case EpubThemeType.light:
        _theme = EpubThemeType.dark;
        _controller.updateTheme(theme: EpubTheme.dark());
      case EpubThemeType.dark:
        _theme = EpubThemeType.custom;
        _controller.updateTheme(theme: _auroraTheme());
    }
    setState(() {});
  }

  EpubTheme _auroraTheme() {
    return EpubTheme.custom(
      backgroundDecoration: const BoxDecoration(color: Color(0xFFF1FAF7)),
      foregroundColor: const Color(0xFF17332B),
      customCss: {
        'body': {
          'font-family': 'Georgia, serif',
          'line-height': '1.65',
          'padding': '8px 10px',
        },
        'p': {
          'font-size': '${_fontSize}px',
        },
      },
    );
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
      EpubThemeType.dark => const Color(0xFF94A3B8),
      EpubThemeType.light => const Color(0xFF2563EB),
      EpubThemeType.custom => const Color(0xFF34D399),
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
              theme: switch (_theme) {
                EpubThemeType.dark => EpubTheme.dark(),
                EpubThemeType.light => EpubTheme.light(),
                EpubThemeType.custom => _auroraTheme(),
              },
            ),
            onTouchUp: _handleViewerTap,
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
            bottom: _showHud ? 16 : -320,
            child: IgnorePointer(
              ignoring: !_showHud,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
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
                          Icon(Icons.auto_stories_rounded, color: accent, size: 18),
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
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: _hudFontFamily,
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _miniChip(
                            label: _hudFontFamily,
                            selected: _hudFontFamily == 'Outfit',
                            onTap: () => setState(() => _hudFontFamily = 'Outfit'),
                          ),
                          _miniChip(
                            label: 'Georgia',
                            selected: _hudFontFamily == 'Georgia',
                            onTap: () => setState(() => _hudFontFamily = 'Georgia'),
                          ),
                          _miniChip(
                            label: 'Delius',
                            selected: _hudFontFamily == 'Delius',
                            onTap: () => setState(() => _hudFontFamily = 'Delius'),
                          ),
                          const SizedBox(width: 4),
                          _miniIcon(
                            icon: Icons.text_decrease_rounded,
                            onTap: () => _changeFontSize(-1),
                          ),
                          Text(
                            _fontSize.toStringAsFixed(0),
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: _hudFontFamily,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
              style: TextStyle(
                color: Colors.white,
                fontFamily: _hudFontFamily,
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

  Widget _miniChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.28)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontFamily: _hudFontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
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
          style: TextStyle(
            color: Colors.white,
            fontFamily: _hudFontFamily,
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
