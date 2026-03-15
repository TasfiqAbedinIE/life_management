class Ebook {
  final String id;
  final String title;
  final String author;
  final String? description;
  final String filePath;
  final String fileType;
  final String? coverPath;
  final List<String> tags;

  Ebook({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    required this.filePath,
    required this.fileType,
    this.coverPath,
    required this.tags,
  });

  factory Ebook.fromMap(Map<String, dynamic> map) {
    return Ebook(
      id: map['id'].toString(),
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      description: map['description'],
      filePath: map['file_path'],
      fileType: map['file_type'],
      coverPath: map['cover_path'],
      tags: _parseTags(map['tags'] ?? map['tag']),
    );
  }

  static List<String> _parseTags(dynamic raw) {
    if (raw == null) return const [];

    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return const [];

    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }
}
