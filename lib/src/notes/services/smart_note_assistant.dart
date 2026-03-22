import '../models/note.dart';

class SmartNoteInsight {
  final String summary;
  final String suggestedTitle;
  final List<String> suggestedTags;
  final List<String> actionItems;
  final String tone;
  final int estimatedReadingMinutes;

  const SmartNoteInsight({
    required this.summary,
    required this.suggestedTitle,
    required this.suggestedTags,
    required this.actionItems,
    required this.tone,
    required this.estimatedReadingMinutes,
  });
}

class SmartNoteAssistant {
  static SmartNoteInsight generate({
    required String title,
    required String content,
    required NoteType type,
  }) {
    final normalized = content
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final summary = _buildSummary(normalized);
    final suggestedTitle = _buildTitle(title: title, lines: normalized, type: type);
    final actionItems = _extractActionItems(normalized);
    final suggestedTags = _buildTags(
      title: title,
      lines: normalized,
      type: type,
      actionItems: actionItems,
    );
    final tone = _inferTone(normalized);
    final words = content
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .length;

    return SmartNoteInsight(
      summary: summary,
      suggestedTitle: suggestedTitle,
      suggestedTags: suggestedTags,
      actionItems: actionItems,
      tone: tone,
      estimatedReadingMinutes: words == 0 ? 1 : (words / 180).ceil(),
    );
  }

  static String _buildSummary(List<String> lines) {
    if (lines.isEmpty) {
      return 'Start writing to generate a local summary.';
    }

    final bullets = lines.where((line) => _isBullet(line)).take(3).toList();
    if (bullets.isNotEmpty) {
      return bullets
          .map((line) => _cleanBullet(line))
          .where((line) => line.isNotEmpty)
          .join(' • ');
    }

    return lines.take(2).join(' ').trim();
  }

  static String _buildTitle({
    required String title,
    required List<String> lines,
    required NoteType type,
  }) {
    if (title.trim().isNotEmpty) {
      return title.trim();
    }

    final firstMeaningfulLine = lines.firstWhere(
      (line) => line.replaceAll(RegExp(r'[-*[\]0-9. ]'), '').isNotEmpty,
      orElse: () => '',
    );
    if (firstMeaningfulLine.isNotEmpty) {
      return _sentenceCase(_cleanBullet(firstMeaningfulLine));
    }

    return '${type.label} draft';
  }

  static List<String> _buildTags({
    required String title,
    required List<String> lines,
    required NoteType type,
    required List<String> actionItems,
  }) {
    final text = '$title ${lines.join(' ')}'.toLowerCase();
    final tags = <String>{type.label.toLowerCase()};

    final keywordMap = <String, List<String>>{
      'meeting': ['meeting', 'agenda', 'follow-up', 'discussion'],
      'work': ['project', 'client', 'deadline', 'deliverable'],
      'personal': ['personal', 'journal', 'reflection'],
      'ideas': ['idea', 'brainstorm', 'concept'],
      'shopping': ['buy', 'purchase', 'shopping', 'grocery'],
      'planning': ['plan', 'roadmap', 'milestone', 'timeline'],
    };

    for (final entry in keywordMap.entries) {
      if (entry.value.any(text.contains)) {
        tags.add(entry.key);
      }
    }

    if (actionItems.isNotEmpty) {
      tags.add('actionable');
    }

    return tags.take(4).toList();
  }

  static List<String> _extractActionItems(List<String> lines) {
    final matches = <String>[];
    final trigger = RegExp(
      r'^(?:-|\*|\[ \]|\[x\]|\d+\.)\s*(.+)$',
      caseSensitive: false,
    );
    final verbLead = RegExp(
      r'^(call|send|review|finish|prepare|share|book|buy|plan|follow up|email|draft)\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      final bulletMatch = trigger.firstMatch(line);
      if (bulletMatch != null) {
        final candidate = bulletMatch.group(1)?.trim() ?? '';
        if (candidate.isNotEmpty) {
          matches.add(_sentenceCase(candidate));
        }
        continue;
      }

      if (verbLead.hasMatch(line)) {
        matches.add(_sentenceCase(line));
      }
    }

    return matches.take(5).toList();
  }

  static String _inferTone(List<String> lines) {
    final text = lines.join(' ').toLowerCase();
    if (text.contains('idea') || text.contains('explore') || text.contains('brainstorm')) {
      return 'Creative';
    }
    if (text.contains('meeting') || text.contains('agenda') || text.contains('decision')) {
      return 'Professional';
    }
    if (text.contains('today') || text.contains('feel') || text.contains('grateful')) {
      return 'Personal';
    }
    return 'Focused';
  }

  static bool _isBullet(String line) {
    return RegExp(r'^(-|\*|\[ \]|\[x\]|\d+\.)\s+').hasMatch(line);
  }

  static String _cleanBullet(String line) {
    return line.replaceFirst(RegExp(r'^(-|\*|\[ \]|\[x\]|\d+\.)\s+'), '').trim();
  }

  static String _sentenceCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}
