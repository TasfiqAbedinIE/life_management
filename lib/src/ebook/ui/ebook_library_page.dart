import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../theme/app_theme.dart';
import '../data/ebook_reading_repository.dart';
import '../data/ebook_repo_supabase.dart';
import '../data/models/ebook.dart';
import '../data/models/ebook_user_state.dart';
import 'epub_reader_page.dart';
import 'pdf_reader_page.dart';

class EbookLibraryPage extends StatefulWidget {
  const EbookLibraryPage({super.key});

  @override
  State<EbookLibraryPage> createState() => _EbookLibraryPageState();
}

class _EbookLibraryPageState extends State<EbookLibraryPage> {
  final _repo = EbookRepoSupabase();
  final _readingRepo = EbookReadingRepository();
  final _dio = Dio();
  final _searchCtrl = TextEditingController();

  late Future<_EbookLibraryData> _future;
  String? _openingBookId;
  final Map<String, double> _downloadProgress = {};
  String _selectedTag = 'All';

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
    final readingStats = await _readingRepo.fetchStats();
    final coverUrls = <String, String>{};

    final booksWithCover = ebooks
        .where((e) => (e.coverPath ?? '').trim().isNotEmpty)
        .toList();

    await Future.wait(
      booksWithCover.map((ebook) async {
        try {
          final signedUrl = await _repo.getSignedCoverUrl(ebook.coverPath);
          if (signedUrl != null && signedUrl.isNotEmpty) {
            coverUrls[ebook.id] = signedUrl;
          }
        } catch (_) {}
      }),
    );

    return _EbookLibraryData(
      ebooks: ebooks,
      userStates: userStates,
      readingStats: readingStats,
      coverUrls: coverUrls,
    );
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
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(ebook.author),
                if ((ebook.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    ebook.description!.trim(),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppPalette.isDark(context)
                          ? const Color(0xFFB9C6DD)
                          : const Color(0xFF374151),
                      height: 1.35,
                    ),
                  ),
                ],
                if (ebook.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ebook.tags
                        .map((tag) => _tinyBadge(tag, const Color(0xFF6366F1)))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                if (progress > 0 && progress < 1)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_arrow_rounded),
                    title: Text('Continue reading (${(progress * 100).toStringAsFixed(0)}%)'),
                    onTap: () {
                      Navigator.pop(context);
                      _openReader(ebook: ebook, state: state);
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    hasLocalCopy ? Icons.offline_pin_outlined : Icons.chrome_reader_mode_outlined,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offline file removed.')),
    );
  }

  void _patchLocalState(String ebookId, EbookUserState newState) {
    if (!mounted) return;

    setState(() {
      _future = _future.then((data) {
        final updated = Map<String, EbookUserState>.from(data.userStates);
        updated[ebookId] = newState;
        return _EbookLibraryData(
          ebooks: data.ebooks,
          userStates: updated,
          readingStats: data.readingStats,
          coverUrls: data.coverUrls,
        );
      });
    });
  }

  Future<void> _recordReadingSession({
    required String ebookId,
    required DateTime startAt,
  }) async {
    final elapsed = DateTime.now().difference(startAt);
    if (elapsed.inSeconds <= 0) return;

    await _readingRepo.addReadingDuration(
      ebookId: ebookId,
      duration: elapsed,
      endedAt: DateTime.now(),
    );

    if (!mounted) return;
    setState(() => _future = _loadData());
  }

  Future<void> _openReader({
    required Ebook ebook,
    required EbookUserState? state,
  }) async {
    setState(() => _openingBookId = ebook.id);

    var pushedReader = false;
    final readingStart = DateTime.now();

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

      pushedReader = true;
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
              resumeKey: ebook.id,
              onProgressChanged: (progress) {
                unawaited(_saveProgress(ebook, state, progress));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open ebook: $e')),
      );
    } finally {
      if (pushedReader) {
        await _recordReadingSession(ebookId: ebook.id, startAt: readingStart);
      }

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

  List<Ebook> _filteredBooks(_EbookLibraryData data) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return data.ebooks.where((ebook) {
      final matchesQuery =
          query.isEmpty ||
          ebook.title.toLowerCase().contains(query) ||
          ebook.author.toLowerCase().contains(query) ||
          ebook.tags.any((tag) => tag.toLowerCase().contains(query));

      if (!matchesQuery) return false;
      if (_selectedTag == 'All') return true;
      return ebook.tags.any(
        (tag) => tag.toLowerCase() == _selectedTag.toLowerCase(),
      );
    }).toList();
  }

  List<Ebook> _currentlyReading(_EbookLibraryData data) {
    final books = data.ebooks.where((ebook) {
      final progress = data.userStates[ebook.id]?.progress ?? 0.0;
      return progress > 0 && progress < 1;
    }).toList();

    books.sort((a, b) {
      final progressA = data.userStates[a.id]?.progress ?? 0.0;
      final progressB = data.userStates[b.id]?.progress ?? 0.0;
      if (progressA != progressB) return progressB.compareTo(progressA);
      final timeA = data.readingStats.totalSecondsByBook[a.id] ?? 0;
      final timeB = data.readingStats.totalSecondsByBook[b.id] ?? 0;
      return timeB.compareTo(timeA);
    });

    return books;
  }

  List<_GenreItem> _genreItems(_EbookLibraryData data) {
    final tags = <String>{};
    for (final ebook in data.ebooks) {
      for (final tag in ebook.tags) {
        tags.add(tag);
      }
    }

    final sortedTags = tags.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final result = <_GenreItem>[];

    for (final tag in sortedTags.take(8)) {
      result.add(_genreStyle(tag));
    }

    if (result.isEmpty) {
      return const [
        _GenreItem('Fantasy', Color(0xFFEDEBFF)),
        _GenreItem('Romance', Color(0xFFFFEEF3)),
        _GenreItem('Mystery', Color(0xFFFFF6DF)),
        _GenreItem('Sci-Fi', Color(0xFFE5F8FB)),
      ];
    }

    return result;
  }

  _GenreItem _genreStyle(String tag) {
    final key = tag.toLowerCase();
    if (key.contains('fantasy')) {
      return const _GenreItem('Fantasy', Color(0xFFEDEBFF));
    }
    if (key.contains('romance')) {
      return const _GenreItem('Romance', Color(0xFFFFEEF3));
    }
    if (key.contains('mystery')) {
      return const _GenreItem('Mystery', Color(0xFFFFF6DF));
    }
    if (key.contains('sci')) {
      return const _GenreItem('Sci-Fi', Color(0xFFE5F8FB));
    }
    if (key.contains('history')) {
      return const _GenreItem('History', Color(0xFFFFF5E3));
    }
    return _GenreItem(tag, const Color(0xFFEEF2FF));
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    return '${totalSeconds}s';
  }

  String _estimatedRemainingText(Ebook ebook, _EbookLibraryData data) {
    final progress = data.userStates[ebook.id]?.progress ?? 0.0;
    final spent = data.readingStats.totalSecondsByBook[ebook.id] ?? 0;

    if (progress <= 0 || progress >= 1 || spent <= 0) {
      return 'Keep reading';
    }

    final estimatedTotal = spent / progress;
    final remaining = (estimatedTotal - spent).round();
    if (remaining <= 0) return 'Almost done';

    return '${_formatDuration(remaining)} left';
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _searchBar() {
    final isDark = AppPalette.isDark(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF101B31).withValues(alpha: 0.82) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFD9E2F0),
          ),
          boxShadow: [
            BoxShadow(
              color: AppPalette.softShadow(context),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: AppPalette.mutedText(context), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search books, authors, genres...',
                  hintStyle: TextStyle(color: AppPalette.mutedText(context)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            Icon(Icons.tune_rounded, color: AppPalette.mutedText(context), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _genresSection(_EbookLibraryData data) {
    final isDark = AppPalette.isDark(context);
    final genres = _genreItems(data);

    return Column(
      children: [
        _sectionHeader('Genres'),
        SizedBox(
          height: 54,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: genres.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final genre = genres[i];
              final selected = _selectedTag.toLowerCase() == genre.label.toLowerCase();

              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  setState(() {
                    _selectedTag = selected ? 'All' : genre.label;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF151E33).withValues(alpha: selected ? 0.95 : 0.75)
                        : genre.lightBackground,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.55)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.11)
                              : const Color(0xFFDCE4F2)),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      genre.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF141A24),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _continueReadingSection(_EbookLibraryData data) {
    final isDark = AppPalette.isDark(context);
    final books = _currentlyReading(data);
    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 18),
        _sectionHeader('Continue Reading'),
        SizedBox(
          height: 166,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final ebook = books[i];
              final progress = (data.userStates[ebook.id]?.progress ?? 0.0).clamp(0.0, 1.0);
              final opening = _openingBookId == ebook.id;

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: opening ? null : () => _openEbookActions(ebook, data.userStates[ebook.id]),
                child: Container(
                  width: 340,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131C31).withValues(alpha: 0.94) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.11)
                          : const Color(0xFFDCE4F2),
                    ),
                  ),
                  child: Row(
                    children: [
                      _bookThumbnail(
                        coverUrl: data.coverUrls[ebook.id],
                        typeColor: const Color(0xFF6366F1),
                        isPdf: ebook.fileType.toLowerCase() == 'pdf',
                        width: 78,
                        height: 110,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              ebook.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ebook.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppPalette.mutedText(context), fontSize: 15),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 8,
                                      backgroundColor: isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : const Color(0xFFE8ECF6),
                                      color: const Color(0xFF7C6BFF),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${(progress * 100).round()}%',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _estimatedRemainingText(ebook, data),
                              style: TextStyle(color: AppPalette.mutedText(context), fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _availableForYouSection(_EbookLibraryData data) {
    final books = _filteredBooks(data);
    return Column(
      children: [
        const SizedBox(height: 18),
        _sectionHeader('Available for You'),
        SizedBox(
          height: 262,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final ebook = books[i];
              final state = data.userStates[ebook.id];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _openingBookId == ebook.id ? null : () => _openEbookActions(ebook, state),
                child: SizedBox(
                  width: 122,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bookThumbnail(
                        coverUrl: data.coverUrls[ebook.id],
                        typeColor: ebook.fileType.toLowerCase() == 'pdf'
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF06B6D4),
                        isPdf: ebook.fileType.toLowerCase() == 'pdf',
                        width: 122,
                        height: 170,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ebook.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ebook.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppPalette.mutedText(context), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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

  Widget _bookThumbnail({
    required String? coverUrl,
    required Color typeColor,
    required bool isPdf,
    double width = 56,
    double height = 72,
  }) {
    if (coverUrl == null || coverUrl.isEmpty) {
      return _fallbackThumbnail(
        typeColor: typeColor,
        isPdf: isPdf,
        width: width,
        height: height,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        coverUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackThumbnail(
          typeColor: typeColor,
          isPdf: isPdf,
          width: width,
          height: height,
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _fallbackThumbnail(
            typeColor: typeColor,
            isPdf: isPdf,
            width: width,
            height: height,
          );
        },
      ),
    );
  }

  Widget _fallbackThumbnail({
    required Color typeColor,
    required bool isPdf,
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
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
        size: width > 70 ? 36 : 28,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppPalette.isDark(context);

    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(
        title: const Text('E-Book Library'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF09111F), Color(0xFF0D1730), Color(0xFF09111F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: FutureBuilder<_EbookLibraryData>(
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
                      FilledButton(onPressed: _refresh, child: const Text('Retry')),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data!;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.only(top: 10, bottom: 24),
                children: [
                  _searchBar(),
                  _genresSection(data),
                  _continueReadingSection(data),
                  _availableForYouSection(data),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EbookLibraryData {
  final List<Ebook> ebooks;
  final Map<String, EbookUserState> userStates;
  final EbookReadingStats readingStats;
  final Map<String, String> coverUrls;

  const _EbookLibraryData({
    required this.ebooks,
    required this.userStates,
    required this.readingStats,
    required this.coverUrls,
  });
}

class _GenreItem {
  final String label;
  final Color lightBackground;

  const _GenreItem(this.label, this.lightBackground);
}
