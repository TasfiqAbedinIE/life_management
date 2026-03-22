enum NoteType { rich, checklist, meeting, idea }

extension NoteTypeX on NoteType {
  String get storageValue => switch (this) {
    NoteType.rich => 'rich',
    NoteType.checklist => 'checklist',
    NoteType.meeting => 'meeting',
    NoteType.idea => 'idea',
  };

  String get label => switch (this) {
    NoteType.rich => 'Note',
    NoteType.checklist => 'Checklist',
    NoteType.meeting => 'Meeting',
    NoteType.idea => 'Idea',
  };

  static NoteType fromStorage(String? value) {
    return NoteType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => NoteType.rich,
    );
  }
}

class Note {
  final int? id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final int colorValue;
  final List<String> tags;
  final NoteType type;

  const Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.colorValue = 0xFFFFF7E8,
    this.tags = const [],
    this.type = NoteType.rich,
  });

  Note copyWith({
    int? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    int? colorValue,
    List<String>? tags,
    NoteType? type,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      colorValue: colorValue ?? this.colorValue,
      tags: tags ?? this.tags,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'is_pinned': isPinned ? 1 : 0,
    'color_value': colorValue,
    'tags_csv': tags.join('|'),
    'note_type': type.storageValue,
  };

  static Note fromMap(Map<String, dynamic> map) => Note(
    id: map['id'] as int?,
    title: (map['title'] as String?) ?? '',
    content: (map['content'] as String?) ?? '',
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    isPinned: (map['is_pinned'] as int? ?? 0) == 1,
    colorValue: (map['color_value'] as int?) ?? 0xFFFFF7E8,
    tags: ((map['tags_csv'] as String?) ?? '')
        .split('|')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList(),
    type: NoteTypeX.fromStorage(map['note_type'] as String?),
  );
}
