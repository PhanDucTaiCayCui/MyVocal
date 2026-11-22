import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';

class ImportSummary {
  final int totalInBackup;
  final int importedCount;
  final int skippedCount;

  const ImportSummary({
    required this.totalInBackup,
    required this.importedCount,
    required this.skippedCount,
  });
}

class BackupService {
  static const String settingLastBackup = 'last_backup_at';

  Future<String?> getLastBackupDate(AppDatabase db) async {
    return await db.getSetting(settingLastBackup);
  }

  Future<bool> exportBackup(AppDatabase db) async {
    final words = await db.getAllWords();
    final reviews = await db.getAllReviews();
    final reviewLogs = await db.getAllReviewLogs();

    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'words': words
          .map((w) => {
                'id': w.id,
                'word': w.word,
                'phonetic': w.phonetic,
                'pos': w.pos,
                'meaningVi': w.meaningVi,
                'example': w.example,
                'notes': w.notes,
                'tags': w.tags,
                'createdAt': w.createdAt.toIso8601String(),
              })
          .toList(),
      'reviews': reviews
          .map((r) => {
                'wordId': r.wordId,
                'dueDate': r.dueDate.toIso8601String(),
                'interval': r.interval,
                'easeFactor': r.easeFactor,
                'repetitions': r.repetitions,
                'lapses': r.lapses,
              })
          .toList(),
      'reviewLogs': reviewLogs
          .map((l) => {
                'id': l.id,
                'wordId': l.wordId,
                'grade': l.grade,
                'reviewedAt': l.reviewedAt.toIso8601String(),
              })
          .toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    final tempDir = await getTemporaryDirectory();
    final fileName =
        'myvocab_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(jsonStr, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      text: 'Bản sao lưu dữ liệu MyVocab (${words.length} từ vựng)',
    );

    await db.setSetting(settingLastBackup, DateTime.now().toIso8601String());
    return true;
  }

  Future<ImportSummary?> importBackup(AppDatabase db, {String? jsonContent}) async {
    String? content = jsonContent;

    if (content == null) {
      final pickResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (pickResult == null || pickResult.files.single.path == null) {
        return null;
      }

      final file = File(pickResult.files.single.path!);
      content = await file.readAsString();
    }

    final Map<String, dynamic> data = jsonDecode(content);
    final rawWords = (data['words'] as List? ?? []);
    final rawReviews = (data['reviews'] as List? ?? []);
    final rawReviewLogs = (data['reviewLogs'] as List? ?? []);

    int importedCount = 0;
    int skippedCount = 0;

    await db.transaction(() async {
      final idMap = <int, int>{}; // oldId -> newWordId

      for (final raw in rawWords) {
        if (raw is! Map<String, dynamic>) continue;
        final rawWordText = (raw['word'] as String?)?.trim().toLowerCase() ?? '';
        if (rawWordText.isEmpty) continue;

        final existing = await db.findWordByText(rawWordText);
        if (existing != null) {
          skippedCount++;
          continue;
        }

        final oldId = raw['id'] as int?;
        final createdAtStr = raw['createdAt'] as String?;
        final createdAt = createdAtStr != null
            ? (DateTime.tryParse(createdAtStr) ?? DateTime.now())
            : DateTime.now();

        final newWordId = await db.into(db.words).insert(
              WordsCompanion.insert(
                word: rawWordText,
                phonetic: Value(raw['phonetic'] as String?),
                pos: Value(raw['pos'] as String?),
                meaningVi: (raw['meaningVi'] as String?) ?? '',
                example: Value(raw['example'] as String?),
                notes: Value(raw['notes'] as String?),
                tags: Value(raw['tags'] as String?),
                createdAt: createdAt,
              ),
            );

        if (oldId != null) {
          idMap[oldId] = newWordId;
        }
        importedCount++;
      }

      // Re-map Reviews
      for (final raw in rawReviews) {
        if (raw is! Map<String, dynamic>) continue;
        final oldWordId = raw['wordId'] as int?;
        if (oldWordId == null || !idMap.containsKey(oldWordId)) continue;
        final newWordId = idMap[oldWordId]!;

        final dueDateStr = raw['dueDate'] as String?;
        final dueDate = dueDateStr != null
            ? (DateTime.tryParse(dueDateStr) ?? DateTime.now())
            : DateTime.now();

        await db.into(db.reviews).insertOnConflictUpdate(
              ReviewsCompanion(
                wordId: Value(newWordId),
                dueDate: Value(dueDate),
                interval: Value((raw['interval'] as int?) ?? 0),
                easeFactor: Value(
                  ((raw['easeFactor'] as num?)?.toDouble()) ?? 2.5,
                ),
                repetitions: Value((raw['repetitions'] as int?) ?? 0),
                lapses: Value((raw['lapses'] as int?) ?? 0),
              ),
            );
      }

      // Re-map ReviewLogs
      for (final raw in rawReviewLogs) {
        if (raw is! Map<String, dynamic>) continue;
        final oldWordId = raw['wordId'] as int?;
        if (oldWordId == null || !idMap.containsKey(oldWordId)) continue;
        final newWordId = idMap[oldWordId]!;

        final reviewedAtStr = raw['reviewedAt'] as String?;
        final reviewedAt = reviewedAtStr != null
            ? (DateTime.tryParse(reviewedAtStr) ?? DateTime.now())
            : DateTime.now();

        await db.into(db.reviewLogs).insert(
              ReviewLogsCompanion.insert(
                wordId: newWordId,
                grade: (raw['grade'] as int?) ?? 4,
                reviewedAt: reviewedAt,
              ),
            );
      }
    });

    return ImportSummary(
      totalInBackup: rawWords.length,
      importedCount: importedCount,
      skippedCount: skippedCount,
    );
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});
