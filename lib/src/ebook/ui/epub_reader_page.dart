import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

class EpubReaderPage extends StatefulWidget {
  const EpubReaderPage({
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
  State<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends State<EpubReaderPage> {
  final _controller = EpubController();
  double _currentProgress = 0.0;
  bool _showHud = true;
  double _fontSize = 18;
  EpubThemeType _theme = EpubThemeType.light;

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.initialProgress.clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    widget.onProgressChanged(_currentProgress);
    super.dispose();
  }

  void _toggleTheme() {
    switch (_theme) {
      case EpubThemeType.light:
        _theme = EpubThemeType.dark;
        _controller.updateTheme(theme: EpubTheme.dark());
      case EpubThemeType.dark:
        _theme = EpubThemeType.custom;
        _controller.updateTheme(
          theme: EpubTheme.custom(
            backgroundDecoration: const BoxDecoration(color: Color(0xFFF8F1DD)),
            foregroundColor: const Color(0xFF3B2F2F),
          ),
        );
      case EpubThemeType.custom:
        _theme = EpubThemeType.light;
        _controller.updateTheme(theme: EpubTheme.light());
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.localFilePath != null
        ? EpubSource.fromFile(File(widget.localFilePath!))
        : EpubSource.fromUrl(widget.sourceUrl!);

    final themeColor = switch (_theme) {
      EpubThemeType.light => const Color(0xFF2563EB),
      EpubThemeType.dark => const Color(0xFF111827),
      EpubThemeType.custom => const Color(0xFFD97706),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Toggle theme',
            onPressed: _toggleTheme,
            icon: const Icon(Icons.palette_outlined),
          ),
          IconButton(
            tooltip: _showHud ? 'Hide controls' : 'Show controls',
            onPressed: () => setState(() => _showHud = !_showHud),
            icon: Icon(_showHud ? Icons.visibility_off : Icons.visibility),
          ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showHud = !_showHud),
            child: EpubViewer(
              epubController: _controller,
              epubSource: source,
              displaySettings: EpubDisplaySettings(
                fontSize: _fontSize.toInt(),
                theme: switch (_theme) {
                  EpubThemeType.dark => EpubTheme.dark(),
                  EpubThemeType.custom => EpubTheme.custom(
                    backgroundDecoration: const BoxDecoration(
                      color: Color(0xFFF8F1DD),
                    ),
                    foregroundColor: const Color(0xFF3B2F2F),
                  ),
                  EpubThemeType.light => EpubTheme.light(),
                },
              ),
              onEpubLoaded: () {
                if (_currentProgress > 0 && _currentProgress < 1) {
                  _controller.toProgressPercentage(_currentProgress);
                }
              },
              onRelocated: (location) {
                setState(() {
                  _currentProgress = location.progress.clamp(0.0, 1.0);
                });
              },
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 12,
            right: 12,
            bottom: _showHud ? 14 : -210,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_stories, color: themeColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: _currentProgress,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(999),
                            color: themeColor,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(_currentProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: _currentProgress,
                        onChanged: (v) => setState(() => _currentProgress = v),
                        onChangeEnd: (v) => _controller.toProgressPercentage(v),
                      ),
                    ),
                    Row(
                      children: [
                        _miniIcon(
                          icon: Icons.skip_previous_rounded,
                          onTap: () => _controller.prev(),
                        ),
                        _miniIcon(
                          icon: Icons.skip_next_rounded,
                          onTap: () => _controller.next(),
                        ),
                        const Spacer(),
                        _miniIcon(
                          icon: Icons.text_decrease_rounded,
                          onTap: () async {
                            final next = (_fontSize - 1).clamp(14, 28);
                            setState(() => _fontSize = next.toDouble());
                            await _controller.setFontSize(fontSize: _fontSize);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            _fontSize.toStringAsFixed(0),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _miniIcon(
                          icon: Icons.text_increase_rounded,
                          onTap: () async {
                            final next = (_fontSize + 1).clamp(14, 28);
                            setState(() => _fontSize = next.toDouble());
                            await _controller.setFontSize(fontSize: _fontSize);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniIcon({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
