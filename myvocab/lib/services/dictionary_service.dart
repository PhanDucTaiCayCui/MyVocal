import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DictionaryResult {
  final String word;
  final String? phonetic;
  final String? partOfSpeech;
  final String? example;
  final List<String> definitions;

  const DictionaryResult({
    required this.word,
    this.phonetic,
    this.partOfSpeech,
    this.example,
    this.definitions = const [],
  });
}

class DictionaryService {
  final Dio _dio;

  DictionaryService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.dictionaryapi.dev/api/v2/entries/en/',
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ),
            );

  Future<DictionaryResult?> lookup(String word) async {
    final cleanWord = word.trim().toLowerCase();
    if (cleanWord.isEmpty) return null;

    try {
      final response = await _dio.get(Uri.encodeComponent(cleanWord));
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

        // Meanings
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

        return DictionaryResult(
          word: (data['word'] as String?) ?? cleanWord,
          phonetic: phonetic,
          partOfSpeech: pos,
          example: example,
          definitions: definitions,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    } catch (_) {
      return null;
    }
    return null;
  }
}

final dictionaryServiceProvider = Provider<DictionaryService>((ref) {
  return DictionaryService();
});
