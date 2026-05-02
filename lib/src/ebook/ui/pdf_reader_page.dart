import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({
    super.key,
    required this.title,
    required this.sourceUrl,
    required this.localFilePath,
    required this.initialProgress,
    required this.onProgressChanged,
  }) : assert(
         (sourceUrl != null && sourceUrl != '') || localFilePath != null,
         'Either sourceUrl or localFilePath is required.',
       );

  final String title;
  final String? sourceUrl;
  final String? localFilePath;
  final double initialProgress;
  final ValueChanged<double> onProgressChanged;

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  PdfController? _controller;
  String? _error;
  int _pagesCount = 0;
  int _currentPage = 1;
  bool _showHud = true;
  String _hudFontFamily = 'Georgia';
  double _hudFontScale = 1.0;
  _PdfReaderPalette _palette = _PdfReaderPalette.midnight;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      Future<PdfDocument> futureDocument;
      if (widget.localFilePath != null) {
        futureDocument = PdfDocument.openFile(widget.localFilePath!);
      } else {
        final sourceUrl = widget.sourceUrl;
        if (sourceUrl == null || sourceUrl.isEmpty) {
          throw Exception('No PDF source provided');
        }
        final bytes = await _downloadPdfBytes(sourceUrl);
        if (!mounted) return;
        futureDocument = PdfDocument.openData(bytes);
      }

      _controller = PdfController(document: futureDocument);
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<Uint8List> _downloadPdfBytes(String sourceUrl) async {
    final res = await http.get(Uri.parse(sourceUrl));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed to download PDF (${res.statusCode})');
    }
    return res.bodyBytes;
  }

  @override
  void dispose() {
    _controller?.dispose();

    if (_pagesCount > 0) {
      final progress = (_currentPage / _pagesCount).clamp(0.0, 1.0);
      widget.onProgressChanged(progress);
    }
    super.dispose();
  }

  Future<void> _openJumpDialog() async {
    if (_pagesCount == 0 || _controller == null) return;
    final ctrl = TextEditingController(text: _currentPage.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Jump to page'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: '1 - $_pagesCount'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final page = int.tryParse(ctrl.text.trim());
                Navigator.pop(context, page);
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();

    if (result == null || _controller == null) return;
    final page = result.clamp(1, _pagesCount);
    _controller!.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final palette = _palette.colors;
    final progress = _pagesCount > 0 ? _currentPage / _pagesCount : 0.0;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        title: Text(
          widget.title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: _hudFontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Jump to page',
            onPressed: _openJumpDialog,
            icon: const Icon(Icons.find_in_page_outlined),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!),
              ),
            );
          }

          if (controller == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [palette.background, palette.backgroundAccent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      color: palette.pageFrame,
                      child: PdfView(
                        controller: controller,
                        onDocumentLoaded: (doc) {
                          _pagesCount = doc.pagesCount;
                          final initialPage = (_pagesCount * widget.initialProgress)
                              .round()
                              .clamp(1, _pagesCount);
                          setState(() => _currentPage = initialPage);
                          controller.jumpToPage(initialPage);
                        },
                        onPageChanged: (page) {
                          setState(() => _currentPage = page);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: (details) {
                    final width = MediaQuery.of(context).size.width;
                    final height = MediaQuery.of(context).size.height;
                    final xRatio = details.localPosition.dx / width;
                    final yRatio = details.localPosition.dy / height;
                    final inMiddleBand =
                        xRatio >= 0.30 &&
                        xRatio <= 0.70 &&
                        yRatio >= 0.18 &&
                        yRatio <= 0.82;
                    if (inMiddleBand) {
                      setState(() => _showHud = !_showHud);
                    }
                  },
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: 14,
                right: 14,
                bottom: _showHud ? 16 : -320,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [palette.hudTop, palette.hudBottom],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: palette.hudBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: palette.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.picture_as_pdf_rounded,
                                color: palette.accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reader HUD',
                                    style: TextStyle(
                                      color: palette.primaryText,
                                      fontFamily: _hudFontFamily,
                                      fontSize: 18 * _hudFontScale,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tap the middle of the screen to show or hide this panel.',
                                    style: TextStyle(
                                      color: palette.secondaryText,
                                      fontFamily: _hudFontFamily,
                                      fontSize: 11 * _hudFontScale,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _pagesCount > 0
                                    ? '${(progress * 100).toStringAsFixed(0)}%'
                                    : '--',
                                style: TextStyle(
                                  color: palette.primaryText,
                                  fontFamily: _hudFontFamily,
                                  fontSize: 14 * _hudFontScale,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _metricPill(
                              label: 'Page',
                              value: _pagesCount > 0 ? '$_currentPage / $_pagesCount' : '--',
                            ),
                            const SizedBox(width: 8),
                            _metricPill(label: 'Mode', value: _palette.label),
                            const SizedBox(width: 8),
                            _metricPill(
                              label: 'Font',
                              value: _fontLabel(_hudFontFamily),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                          color: palette.accent,
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                        ),
                        const SizedBox(height: 10),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            activeTrackColor: palette.accent,
                            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                            thumbColor: palette.accent,
                            overlayColor: palette.accent.withValues(alpha: 0.12),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          ),
                          child: Slider(
                            value: _pagesCount > 0
                                ? _currentPage.toDouble().clamp(1, _pagesCount.toDouble())
                                : 1,
                            min: 1,
                            max: (_pagesCount > 0 ? _pagesCount : 1).toDouble(),
                            onChanged: _pagesCount > 0
                                ? (v) => setState(() => _currentPage = v.round())
                                : null,
                            onChangeEnd: (v) {
                              if (_pagesCount > 0) controller.jumpToPage(v.round());
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _sectionLabel('Display')),
                            TextButton.icon(
                              onPressed: _openJumpDialog,
                              icon: const Icon(Icons.find_in_page_outlined),
                              label: const Text('Jump'),
                              style: TextButton.styleFrom(
                                foregroundColor: palette.primaryText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _choiceChip(
                              label: 'Modern',
                              selected: _hudFontFamily == 'Outfit',
                              onTap: () => setState(() => _hudFontFamily = 'Outfit'),
                            ),
                            _choiceChip(
                              label: 'Serif',
                              selected: _hudFontFamily == 'Georgia',
                              onTap: () => setState(() => _hudFontFamily = 'Georgia'),
                            ),
                            _choiceChip(
                              label: 'Mono',
                              selected: _hudFontFamily == 'Courier',
                              onTap: () => setState(() => _hudFontFamily = 'Courier'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _miniIcon(
                              icon: Icons.text_decrease_rounded,
                              onTap: () {
                                setState(() {
                                  _hudFontScale = (_hudFontScale - 0.1).clamp(0.85, 1.35);
                                });
                              },
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  activeTrackColor: palette.accent,
                                  inactiveTrackColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  thumbColor: palette.accent,
                                ),
                                child: Slider(
                                  value: _hudFontScale,
                                  min: 0.85,
                                  max: 1.35,
                                  onChanged: (value) {
                                    setState(() => _hudFontScale = value);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _miniIcon(
                              icon: Icons.text_increase_rounded,
                              onTap: () {
                                setState(() {
                                  _hudFontScale = (_hudFontScale + 0.1).clamp(0.85, 1.35);
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _sectionLabel('Atmosphere'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final paletteOption in _PdfReaderPalette.values)
                              _paletteChip(paletteOption),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'This PDF renderer supports page rendering and navigation, but not real PDF text reflow, font replacement, or built-in text marking. For selectable highlights, we would need a different PDF stack.',
                            style: TextStyle(
                              color: palette.secondaryText,
                              fontFamily: _hudFontFamily,
                              fontSize: 11 * _hudFontScale,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _miniIcon({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _metricPill({required String label, required String value}) {
    final palette = _palette.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.secondaryText,
              fontFamily: _hudFontFamily,
              fontSize: 10 * _hudFontScale,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: palette.primaryText,
              fontFamily: _hudFontFamily,
              fontSize: 13 * _hudFontScale,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final palette = _palette.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? palette.accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? palette.accent : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: palette.primaryText,
            fontFamily: _hudFontFamily,
            fontSize: 12 * _hudFontScale,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _paletteChip(_PdfReaderPalette paletteOption) {
    final selected = _palette == paletteOption;
    final optionColors = paletteOption.colors;
    return InkWell(
      onTap: () => setState(() => _palette = paletteOption),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? optionColors.accent : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: optionColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              paletteOption.label,
              style: TextStyle(
                color: _palette.colors.primaryText,
                fontFamily: _hudFontFamily,
                fontSize: 12 * _hudFontScale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _palette.colors.secondaryText,
        fontFamily: _hudFontFamily,
        fontSize: 11 * _hudFontScale,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }

  String _fontLabel(String family) {
    switch (family) {
      case 'Outfit':
        return 'Modern';
      case 'Courier':
        return 'Mono';
      default:
        return 'Serif';
    }
  }
}

enum _PdfReaderPalette {
  midnight('Midnight'),
  ember('Ember'),
  forest('Forest');

  const _PdfReaderPalette(this.label);

  final String label;

  _PdfPaletteColors get colors {
    switch (this) {
      case _PdfReaderPalette.midnight:
        return const _PdfPaletteColors(
          background: Color(0xFF0B1020),
          backgroundAccent: Color(0xFF1F2A44),
          pageFrame: Color(0xFFE5ECF6),
          hudTop: Color(0xFF111827),
          hudBottom: Color(0xFF1F2937),
          hudBorder: Color(0x334B5563),
          accent: Color(0xFF60A5FA),
          primaryText: Color(0xFFF8FAFC),
          secondaryText: Color(0xFFCBD5E1),
        );
      case _PdfReaderPalette.ember:
        return const _PdfPaletteColors(
          background: Color(0xFF2B1711),
          backgroundAccent: Color(0xFF5B211A),
          pageFrame: Color(0xFFF6EBDD),
          hudTop: Color(0xFF3B1410),
          hudBottom: Color(0xFF6B241B),
          hudBorder: Color(0x33F59E0B),
          accent: Color(0xFFF59E0B),
          primaryText: Color(0xFFFFF7ED),
          secondaryText: Color(0xFFFED7AA),
        );
      case _PdfReaderPalette.forest:
        return const _PdfPaletteColors(
          background: Color(0xFF0F1D18),
          backgroundAccent: Color(0xFF1E4633),
          pageFrame: Color(0xFFEAF4EC),
          hudTop: Color(0xFF10261D),
          hudBottom: Color(0xFF1D3A2D),
          hudBorder: Color(0x3334D399),
          accent: Color(0xFF34D399),
          primaryText: Color(0xFFF0FDF4),
          secondaryText: Color(0xFFBBF7D0),
        );
    }
  }
}

class _PdfPaletteColors {
  const _PdfPaletteColors({
    required this.background,
    required this.backgroundAccent,
    required this.pageFrame,
    required this.hudTop,
    required this.hudBottom,
    required this.hudBorder,
    required this.accent,
    required this.primaryText,
    required this.secondaryText,
  });

  final Color background;
  final Color backgroundAccent;
  final Color pageFrame;
  final Color hudTop;
  final Color hudBottom;
  final Color hudBorder;
  final Color accent;
  final Color primaryText;
  final Color secondaryText;
}
