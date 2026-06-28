import 'dart:convert';

import 'package:http/http.dart' as http;

class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.definitions,
  });

  final String word;
  final List<DictionaryDefinition> definitions;
}

class DictionaryDefinition {
  const DictionaryDefinition({
    required this.partOfSpeech,
    required this.definition,
    this.example,
  });

  final String partOfSpeech;
  final String definition;
  final String? example;
}

class EbookDictionaryService {
  static const _baseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en';

  Future<DictionaryEntry> define(String rawWord) async {
    final word = _cleanWord(rawWord);
    if (word == null) {
      throw const DictionaryLookupException('Select a single word to define.');
    }

    final uri = Uri.parse('$_baseUrl/${Uri.encodeComponent(word)}');
    final res = await http.get(uri);

    if (res.statusCode == 404) {
      throw DictionaryLookupException('No definition found for "$word".');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw const DictionaryLookupException(
        'Dictionary is unavailable right now.',
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List || decoded.isEmpty) {
      throw DictionaryLookupException('No definition found for "$word".');
    }

    final definitions = <DictionaryDefinition>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      final meanings = entry['meanings'];
      if (meanings is! List) continue;

      for (final meaning in meanings) {
        if (meaning is! Map<String, dynamic>) continue;
        final partOfSpeech = (meaning['partOfSpeech'] ?? '').toString();
        final rawDefinitions = meaning['definitions'];
        if (rawDefinitions is! List) continue;

        for (final rawDefinition in rawDefinitions) {
          if (rawDefinition is! Map<String, dynamic>) continue;
          final definition = (rawDefinition['definition'] ?? '').toString();
          if (definition.trim().isEmpty) continue;

          final example = rawDefinition['example']?.toString();
          definitions.add(
            DictionaryDefinition(
              partOfSpeech: partOfSpeech.trim().isEmpty
                  ? 'definition'
                  : partOfSpeech.trim(),
              definition: definition.trim(),
              example: example?.trim().isEmpty == true ? null : example?.trim(),
            ),
          );

          if (definitions.length >= 3) {
            return DictionaryEntry(word: word, definitions: definitions);
          }
        }
      }
    }

    if (definitions.isEmpty) {
      throw DictionaryLookupException('No definition found for "$word".');
    }

    return DictionaryEntry(word: word, definitions: definitions);
  }

  String? cleanSelectedWord(String rawWord) => _cleanWord(rawWord);

  String? _cleanWord(String rawWord) {
    final normalized = rawWord
        .replaceAll(RegExp(r'[\n\r\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty || normalized.contains(' ')) return null;

    final match = RegExp(r"[A-Za-z][A-Za-z'-]*").firstMatch(normalized);
    final word = match?.group(0)?.toLowerCase();
    if (word == null || word.isEmpty) return null;
    return word;
  }
}

class DictionaryLookupException implements Exception {
  const DictionaryLookupException(this.message);

  final String message;

  @override
  String toString() => message;
}
