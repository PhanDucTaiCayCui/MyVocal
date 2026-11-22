import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DictionaryResult {
  final String word;
  final String? phonetic;
  final String? partOfSpeech;
  final String? example;
  final List<String> definitions;
  final String? meaningVi;
  final String? exampleVi;
  final List<String> vietnameseMeanings;

  const DictionaryResult({
    required this.word,
    this.phonetic,
    this.partOfSpeech,
    this.example,
    this.definitions = const [],
    this.meaningVi,
    this.exampleVi,
    this.vietnameseMeanings = const [],
  });
}

class DictionaryService {
  final Dio _dio;

  DictionaryService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ),
            );

  Future<DictionaryResult?> lookup(String word) async {
    final cleanWord = word.trim().toLowerCase();
    if (cleanWord.isEmpty) return null;

    // Run DictionaryAPI and Google Translate in parallel
    final dictFuture = _fetchDictionaryApi(cleanWord);
    final translateFuture = _translateWord(cleanWord);

    final dictResult = await dictFuture;
    final translateResult = await translateFuture;

    if (dictResult == null && translateResult == null) {
      return null;
    }

    final example = dictResult?.example;
    String? exampleVi;

    if (example != null && example.trim().isNotEmpty) {
      exampleVi = await _translateSentence(example);
    }

    return DictionaryResult(
      word: dictResult?.word ?? cleanWord,
      phonetic: dictResult?.phonetic,
      partOfSpeech: dictResult?.partOfSpeech,
      example: example,
      definitions: dictResult?.definitions ?? const [],
      meaningVi: translateResult?.primary,
      exampleVi: exampleVi,
      vietnameseMeanings: translateResult?.alternatives ?? const [],
    );
  }

  Future<({String? word, String? phonetic, String? partOfSpeech, String? example, List<String> definitions})?>
      _fetchDictionaryApi(String word) async {
    try {
      final url = 'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word)}';
      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data is List && (response.data as List).isNotEmpty) {
        final data = response.data[0] as Map<String, dynamic>;

        // Phonetic
        String? phonetic = data['phonetic'] as String?;
        if (phonetic == null || phonetic.trim().isEmpty) {
          final phonetics = data['phonetics'] as List?;
          if (phonetics != null) {
            for (final p in phonetics) {
              if (p is Map && p['text'] != null && (p['text'] as String).trim().isNotEmpty) {
                phonetic = p['text'] as String;
                break;
              }
            }
          }
        }

        // Meanings & definitions
        final meanings = data['meanings'] as List?;
        String? pos;
        String? example;
        final definitions = <String>[];

        if (meanings != null && meanings.isNotEmpty) {
          final posList = <String>[];
          for (final m in meanings) {
            if (m is Map) {
              final currentPos = m['partOfSpeech'] as String?;
              if (currentPos != null && currentPos.isNotEmpty) {
                posList.add(currentPos);
              }
              final defs = m['definitions'] as List?;
              if (defs != null) {
                for (final d in defs) {
                  if (d is Map) {
                    final defText = d['definition'] as String?;
                    if (defText != null && defText.trim().isNotEmpty) {
                      final prefix = currentPos != null ? '($currentPos) ' : '';
                      definitions.add('$prefix$defText');
                    }
                    if (example == null) {
                      final ex = d['example'] as String?;
                      if (ex != null && ex.trim().isNotEmpty) {
                        example = ex.trim();
                      }
                    }
                  }
                }
              }
            }
          }
          if (posList.isNotEmpty) {
            pos = posList.first;
          }
        }

        return (
          word: (data['word'] as String?) ?? word,
          phonetic: phonetic,
          partOfSpeech: pos,
          example: example,
          definitions: definitions,
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<({String? primary, List<String> alternatives})?> _translateWord(String word) async {
    try {
      final url =
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=vi&dt=t&dt=bd&q=${Uri.encodeComponent(word)}';
      final res = await _dio.get(url);

      if (res.statusCode == 200 && res.data is List) {
        final data = res.data as List;
        String? primary;
        final alternatives = <String>[];

        // 1. Primary translation from data[0][0][0]
        if (data.isNotEmpty && data[0] is List) {
          final sentences = data[0] as List;
          if (sentences.isNotEmpty && sentences[0] is List) {
            final first = sentences[0] as List;
            if (first.isNotEmpty && first[0] is String) {
              primary = (first[0] as String).trim();
            }
          }
        }

        // 2. Alternative translations / synonyms from data[1]
        if (data.length > 1 && data[1] is List) {
          final dictEntries = data[1] as List;
          for (final entry in dictEntries) {
            if (entry is List && entry.length > 1 && entry[1] is List) {
              final wordsList = entry[1] as List;
              for (final w in wordsList) {
                if (w is String && w.trim().isNotEmpty) {
                  final cleanW = w.trim();
                  if (!alternatives.contains(cleanW)) {
                    alternatives.add(cleanW);
                  }
                }
              }
            }
          }
        }

        if (primary != null && !alternatives.contains(primary)) {
          alternatives.insert(0, primary);
        }

        return (primary: primary, alternatives: alternatives);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<String?> _translateSentence(String sentence) async {
    try {
      final url =
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=vi&dt=t&q=${Uri.encodeComponent(sentence)}';
      final res = await _dio.get(url);

      if (res.statusCode == 200 && res.data is List) {
        final data = res.data as List;
        if (data.isNotEmpty && data[0] is List) {
          final parts = data[0] as List;
          final buffer = StringBuffer();
          for (final part in parts) {
            if (part is List && part.isNotEmpty && part[0] is String) {
              buffer.write(part[0]);
            }
          }
          final translated = buffer.toString().trim();
          return translated.isNotEmpty ? translated : null;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

final dictionaryServiceProvider = Provider<DictionaryService>((ref) {
  return DictionaryService();
});
