class EbookUserState {
  final String ebookId;
  final bool downloaded;
  final double progress;
  final String? localPath;

  EbookUserState({
    required this.ebookId,
    required this.downloaded,
    required this.progress,
    this.localPath,
  });

  factory EbookUserState.fromMap(Map<String, dynamic> map) {
    return EbookUserState(
      ebookId: map['ebook_id'],
      downloaded: map['downloaded'] ?? false,
      progress: (map['progress'] ?? 0).toDouble(),
      localPath: map['local_path'],
    );
  }
}
