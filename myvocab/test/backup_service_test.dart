import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvocab/data/database.dart';
import 'package:myvocab/services/backup_service.dart';

void main() {
  late AppDatabase db;
  late BackupService backupService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;'),
    ));
    backupService = BackupService();
  });

  tearDown(() async {
    await db.close();
  });

  group('BackupService Tests', () {
    test('importBackup skips duplicates and remaps foreign keys for new words', () async {
      // 1. Existing word in DB
      await db.insertWordWithReview(
        wordCompanion: WordsCompanion.insert(
          word: 'resilience',
          meaningVi: 'sự kiên cường',
          createdAt: DateTime(2026, 11, 20),
        ),
      );

      // 2. Backup JSON data containing:
      // - "Resilience" (duplicate, should be skipped)
      // - "ubiquitous" (new word, id: 99 in backup)
      final backupData = {
        'version': 1,
        'exportedAt': DateTime(2026, 11, 22).toIso8601String(),
        'words': [
          {
            'id': 1,
            'word': 'Resilience', // Case-insensitive duplicate
            'meaningVi': 'sự kiên cường',
            'createdAt': DateTime(2026, 11, 20).toIso8601String(),
          },
          {
            'id': 99,
            'word': 'ubiquitous',
            'phonetic': '/juːˈbɪk.wə.təs/',
            'pos': 'adjective',
            'meaningVi': 'phổ biến, có mặt ở khắp nơi',
            'example': 'Mobile phones are ubiquitous.',
            'notes': 'Good vocabulary',
            'tags': ',c1,advanced,',
            'createdAt': DateTime(2026, 11, 21).toIso8601String(),
          },
        ],
        'reviews': [
          {
            'wordId': 99,
            'dueDate': DateTime(2026, 11, 25).toIso8601String(),
            'interval': 6,
            'easeFactor': 2.6,
            'repetitions': 2,
            'lapses': 0,
          },
        ],
        'reviewLogs': [
          {
            'id': 500,
            'wordId': 99,
            'grade': 5,
            'reviewedAt': DateTime(2026, 11, 21, 10, 0).toIso8601String(),
          },
        ],
      };

      final jsonContent = jsonEncode(backupData);

      final summary = await backupService.importBackup(
        db,
        jsonContent: jsonContent,
      );

      expect(summary, isNotNull);
      expect(summary!.totalInBackup, equals(2));
      expect(summary.importedCount, equals(1)); // only ubiquitous
      expect(summary.skippedCount, equals(1)); // resilience skipped

      // Verify the new word exists in DB
      final importedWord = await db.findWordByText('ubiquitous');
      expect(importedWord, isNotNull);
      expect(importedWord!.word, equals('ubiquitous'));

      // Verify the foreign key was correctly re-mapped to importedWord.id
      final review = await db.getReviewForWord(importedWord.id);
      expect(review, isNotNull);
      expect(review!.interval, equals(6));
      expect(review.easeFactor, equals(2.6));
      expect(review.repetitions, equals(2));

      // Verify review log was also re-mapped to importedWord.id
      final logs = await (db.select(db.reviewLogs)
            ..where((t) => t.wordId.equals(importedWord.id)))
          .get();
      expect(logs.length, equals(1));
      expect(logs.first.grade, equals(5));
      expect(logs.first.wordId, equals(importedWord.id));
    });
  });
}
