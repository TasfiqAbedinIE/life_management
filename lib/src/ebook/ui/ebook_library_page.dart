import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/ebook_repo_supabase.dart';
import '../data/models/ebook.dart';
import '../data/models/ebook_user_state.dart';
import 'epub_reader_page.dart';
import 'pdf_reader_page.dart';

enum _LibraryFilter { all, offline, inProgress, pdf, epub }

class EbookLibraryPage extends StatefulWidget {
  const EbookLibraryPage({super.key});

  @override
  State<EbookLibraryPage> createState() => _EbookLibraryPageState();
}

class _EbookLibraryPageState extends State<EbookLibraryPage> {
  final _repo = EbookRepoSupabase();
  final _dio = Dio();
  final _searchCtrl = TextEditingController();

  late Future<_EbookLibraryData> _future;
  String? _openingBookId;
  final Map<String, double> _downloadProgress = {};
  _LibraryFilter _filter = _LibraryFilter.all;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<_EbookLibraryData> _loadData() async {
    final ebooks = await _repo.fetchEbooks();
    final userStates = await _repo.fetchUserStates();
    return _EbookLibraryData(ebooks: ebooks, userStates: userStates);
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadData());
    await _future;
  }

  Future<bool> _hasLocalCopy(EbookUserState? state) async {
    final path = state?.localPath;
    if (path == null || path.isEmpty) return false;
    return File(path).exists();
  }

  Future<void> _openEbookActions(Ebook ebook, EbookUserState? state) async {
    final progress = (state?.progress ?? 0.0).clamp(0.0, 1.0);
    final hasLocalCopy = await _hasLocalCopy(state);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final downloading = _downloadProgress.containsKey(ebook.id);
        final downloadPct = ((_downloadProgress[ebook.id] ?? 0) * 100)
            .clamp(0, 100)
            .toStringAsFixed(0);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ebook.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(ebook.author),
                const SizedBox(height: 14),
                if (progress > 0 && progress < 1)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_arrow_rounded),
                    title: Text(
                      'Continue reading (${(progress * 100).toStringAsFixed(0)}%)',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _openReader(ebook: ebook, state: state);
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    hasLocalCopy
                        ? Icons.offline_pin_outlined
                        : Icons.chrome_reader_mode_outlined,
                  ),
                  title: Text(hasLocalCopy ? 'Read offline' : 'Read now'),
                  onTap: () {
                    Navigator.pop(context);
                    _openReader(ebook: ebook, state: state);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: downloading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                  title: Text(
                    downloading
                        ? 'Downloading... $downloadPct%'
                        : hasLocalCopy
                        ? 'Re-download'
                        : 'Download for offline',
                  ),
                  onTap: downloading
                      ? null
                      : () {
                          Navigator.pop(context);
                          _downloadEbook(ebook: ebook, previousState: state);
                        },
                ),
                if (hasLocalCopy)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Remove download'),
                    onTap: () {
                      Navigator.pop(context);
                      _removeDownload(ebook: ebook, previousState: state);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _buildLocalPath(Ebook ebook) async {
    final dir = await getApplicationDocumentsDirectory();
    final ebooksDir = Directory(p.join(dir.path, 'ebooks'));
    if (!await ebooksDir.exists()) {
      await ebooksDir.create(recursive: true);
    }

    final rawExt = p.extension(ebook.filePath);
    final ext = rawExt.isNotEmpty ? rawExt : '.${ebook.fileType.toLowerCase()}';
    final safeId = ebook.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return p.join(ebooksDir.path, '$safeId$ext');
  }

  Future<void> _downloadEbook({
    required Ebook ebook,
    required EbookUserState? previousState,
  }) async {
    if (_downloadProgress.containsKey(ebook.id)) return;

    setState(() => _downloadProgress[ebook.id] = 0);

    String? targetPath;
    try {
      final signedUrl = await _repo.getSignedEbookUrl(ebook.filePath);
      targetPath = await _buildLocalPath(ebook);

      await _dio.download(
        signedUrl,
        targetPath,
        onReceiveProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _downloadProgress[ebook.id] = received / total);
        },
      );

      final progress = (previousState?.progress ?? 0.0).clamp(0.0, 1.0);
      await _repo.upsertUserState(
        ebookId: ebook.id,
        downloaded: true,
        progress: progress,
        localPath: targetPath,
      );

      _patchLocalState(
        ebook.id,
        EbookUserState(
          ebookId: ebook.id,
          downloaded: true,
          progress: progress,
          localPath: targetPath,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloaded for offline reading.')),
      );
    } catch (e) {
      if (targetPath != null) {
        final file = File(targetPath);
        if (await file.exists()) await file.delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    } finally {
      if (mounted) setState(() => _downloadProgress.remove(ebook.id));
    }
  }

  Future<void> _removeDownload({
    required Ebook ebook,
    required EbookUserState? previousState,
  }) async {
    final localPath = previousState?.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) await file.delete();
    }

    await _repo.upsertUserState(
      ebookId: ebook.id,
      downloaded: false,
      progress: (previousState?.progress ?? 0.0).clamp(0.0, 1.0),
      localPath: null,
    );

    _patchLocalState(
      ebook.id,
      EbookUserState(
        ebookId: ebook.id,
        downloaded: false,
        progress: (previousState?.progress ?? 0.0).clamp(0.0, 1.0),
        localPath: null,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Offline file removed.')));
  }

  void _patchLocalState(String ebookId, EbookUserState newState) {
    if (!mounted) return;

    setState(() {
      _future = _future.then((data) {
        final updated = Map<String, EbookUserState>.from(data.userStates);
        updated[ebookId] = newState;
        return _EbookLibraryData(ebooks: data.ebooks, userStates: updated);
      });
    });
  }

  Future<void> _openReader({
    required Ebook ebook,
    required EbookUserState? state,
  }) async {
    setState(() => _openingBookId = ebook.id);

    try {
      String? localPath;
      String? remoteUrl;

      if (await _hasLocalCopy(state)) {
        localPath = state?.localPath;
      } else {
        remoteUrl = await _repo.getSignedEbookUrl(ebook.filePath);

        if (state?.downloaded == true) {
          final progress = (state?.progress ?? 0.0).clamp(0.0, 1.0);
          await _repo.upsertUserState(
            ebookId: ebook.id,
            downloaded: false,
            progress: progress,
            localPath: null,
          );
          _patchLocalState(
            ebook.id,
            EbookUserState(
              ebookId: ebook.id,
              downloaded: false,
              progress: progress,
              localPath: null,
            ),
          );
        }
      }

      if (!mounted) return;

      final initialProgress = (state?.progress ?? 0.0).clamp(0.0, 1.0);
      final isPdf = ebook.fileType.toLowerCase() == 'pdf';

      if (isPdf) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PdfReaderPage(
              title: ebook.title,
              sourceUrl: remoteUrl,
              localFilePath: localPath,
              initialProgress: initialProgress,
              onProgressChanged: (progress) {
                unawaited(_saveProgress(ebook, state, progress));
              },
            ),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EpubReaderPage(
              title: ebook.title,
              sourceUrl: remoteUrl,
              localFilePath: localPath,
              initialProgress: initialProgress,
              onProgressChanged: (progress) {
                unawaited(_saveProgress(ebook, state, progress));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to open ebook: $e')));
    } finally {
      if (mounted) setState(() => _openingBookId = null);
    }
  }

  Future<void> _saveProgress(
    Ebook ebook,
    EbookUserState? previous,
    double progress,
  ) async {
    final safeProgress = progress.clamp(0.0, 1.0);
    final localPath = previous?.localPath;
    final downloaded =
        previous?.downloaded == true && await _hasLocalCopy(previous);

    await _repo.upsertUserState(
      ebookId: ebook.id,
      downloaded: downloaded,
      progress: safeProgress,
      localPath: downloaded ? localPath : null,
    );

    _patchLocalState(
      ebook.id,
      EbookUserState(
        ebookId: ebook.id,
        downloaded: downloaded,
        progress: safeProgress.toDouble(),
        localPath: downloaded ? localPath : null,
      ),
    );
  }

  List<Ebook> _visibleEbooks(_EbookLibraryData data) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return data.ebooks.where((ebook) {
      final state = data.userStates[ebook.id];
      final matchesQuery =
          query.isEmpty ||
          ebook.title.toLowerCase().contains(query) ||
          ebook.author.toLowerCase().contains(query);

      if (!matchesQuery) return false;

      switch (_filter) {
        case _LibraryFilter.all:
          return true;
        case _LibraryFilter.offline:
          return state?.downloaded == true;
        case _LibraryFilter.inProgress:
          final p = state?.progress ?? 0;
          return p > 0 && p < 1;
        case _LibraryFilter.pdf:
          return ebook.fileType.toLowerCase() == 'pdf';
        case _LibraryFilter.epub:
          return ebook.fileType.toLowerCase() == 'epub';
      }
    }).toList();
  }

  Widget _topHeader(_EbookLibraryData data) {
    final total = data.ebooks.length;
    final offline = data.userStates.values.where((s) => s.downloaded).length;
    final reading = data.userStates.values
        .where((s) => s.progress > 0 && s.progress < 1)
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Digital Library',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          // const Text(
          //   'Read online or offline, and continue where you stopped.',
          //   style: TextStyle(color: Colors.white70),
          // ),
          // const SizedBox(height: 14),
          Row(
            children: [
              _statChip('Books', '$total'),
              const SizedBox(width: 8),
              _statChip('Offline', '$offline'),
              const SizedBox(width: 8),
              _statChip('Reading', '$reading'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _filterChips() {
    final labels = <_LibraryFilter, String>{
      _LibraryFilter.all: 'All',
      _LibraryFilter.offline: 'Offline',
      _LibraryFilter.inProgress: 'In Progress',
      _LibraryFilter.pdf: 'PDF',
      _LibraryFilter.epub: 'EPUB',
    };

    return SizedBox(
      height: 42,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: labels.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: _filter == entry.key,
              onSelected: (_) => setState(() => _filter = entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bookCard({
    required Ebook ebook,
    required EbookUserState? state,
    required bool opening,
    required double? downloading,
  }) {
    final isPdf = ebook.fileType.toLowerCase() == 'pdf';
    final typeColor = isPdf ? const Color(0xFFEF4444) : const Color(0xFF06B6D4);
    final progress = ((state?.progress ?? 0.0) * 100).clamp(0, 100).toDouble();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: opening ? null : () => _openEbookActions(ebook, state),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [typeColor.withValues(alpha: 0.9), typeColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.menu_book_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ebook.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ebook.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _tinyBadge(isPdf ? 'PDF' : 'EPUB', typeColor),
                      if (state?.downloaded == true)
                        _tinyBadge('Offline', const Color(0xFF10B981)),
                      if (progress > 0)
                        _tinyBadge(
                          '${progress.toStringAsFixed(0)}%',
                          const Color(0xFF2563EB),
                        ),
                    ],
                  ),
                  if (downloading != null || progress > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: downloading ?? (progress / 100),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            opening || downloading != null
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: downloading,
                    ),
                  )
                : const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Widget _tinyBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(title: const Text('E-Book Library'), centerTitle: true),
      body: FutureBuilder<_EbookLibraryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snapshot.error.toString()),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final visible = _visibleEbooks(data);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 22),
              children: [
                _topHeader(data),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by title or author...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _filterChips(),
                const SizedBox(height: 8),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text('No matching books found')),
                  )
                else
                  ...visible.map((ebook) {
                    final state = data.userStates[ebook.id];
                    return _bookCard(
                      ebook: ebook,
                      state: state,
                      opening: _openingBookId == ebook.id,
                      downloading: _downloadProgress[ebook.id],
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EbookLibraryData {
  final List<Ebook> ebooks;
  final Map<String, EbookUserState> userStates;

  const _EbookLibraryData({required this.ebooks, required this.userStates});
}
