class Ebook {
  final String id;
  final String title;
  final String author;
  final String? description;
  final String filePath;
  final String fileType; // pdf | epub
  final String? coverPath;

  Ebook({
    required this.id,
    required this.title,
    required this.author,
    this.description,
    required this.filePath,
    required this.fileType,
    this.coverPath,
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
    );
  }
}
