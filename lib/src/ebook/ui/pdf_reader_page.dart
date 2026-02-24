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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Jump to page',
            onPressed: _openJumpDialog,
            icon: const Icon(Icons.find_in_page_outlined),
          ),
          IconButton(
            tooltip: _showHud ? 'Hide controls' : 'Show controls',
            onPressed: () => setState(() => _showHud = !_showHud),
            icon: Icon(_showHud ? Icons.visibility_off : Icons.visibility),
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
              GestureDetector(
                onTap: () => setState(() => _showHud = !_showHud),
                child: PdfView(
                  controller: controller,
                  onDocumentLoaded: (doc) {
                    _pagesCount = doc.pagesCount;
                    final initialPage = (_pagesCount * widget.initialProgress)
                        .round()
                        .clamp(1, _pagesCount);
                    controller.jumpToPage(initialPage);
                  },
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: 12,
                right: 12,
                bottom: _showHud ? 14 : -220,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: _pagesCount > 0 ? _currentPage / _pagesCount : 0,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.redAccent,
                                backgroundColor: Colors.white24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _pagesCount > 0 ? '$_currentPage / $_pagesCount' : '--',
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
                        Row(
                          children: [
                            _miniIcon(
                              icon: Icons.skip_previous_rounded,
                              onTap: () async {
                                if (_currentPage <= 1) return;
                                await controller.previousPage(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                );
                              },
                            ),
                            _miniIcon(
                              icon: Icons.skip_next_rounded,
                              onTap: () async {
                                if (_pagesCount == 0 || _currentPage >= _pagesCount) return;
                                await controller.nextPage(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                );
                              },
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _openJumpDialog,
                              icon: const Icon(Icons.find_in_page_outlined),
                              label: const Text('Jump'),
                              style: TextButton.styleFrom(foregroundColor: Colors.white),
                            ),
                          ],
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
