import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myvocab/data/database.dart';
import 'package:myvocab/domain/sm2.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;'),
    ));
  });

  tearDown(() async {
    await db.close();
  });

  group('Database Tests', () {
    test('insertWordWithReview creates word and review row with defaults', () async {
      final now = DateTime.now();
      final wordId = await db.insertWordWithReview(
        wordCompanion: WordsCompanion.insert(
          word: 'resilience',
          phonetic: const Value('/rɪˈzɪl.jəns/'),
          pos: const Value('noun'),
          meaningVi: 'sự kiên cường, khả năng phục hồi',
          example: const Value('She showed great resilience.'),
          notes: const Value('Important word for IELTS'),
          tags: const Value(',ielts,c1,'),
          createdAt: now,
        ),
      );

      final word = await db.getWordById(wordId);
      expect(word, isNotNull);
      expect(word!.word, equals('resilience'));
      expect(word.pos, equals('noun'));

      final review = await db.getReviewForWord(wordId);
      expect(review, isNotNull);
      expect(review!.wordId, equals(wordId));
      expect(review.interval, equals(0));
      expect(review.easeFactor, equals(2.5));
      expect(review.repetitions, equals(0));
      expect(review.lapses, equals(0));
    });

    test('findWordByText is case-insensitive', () async {
      await db.insertWordWithReview(
        wordCompanion: WordsCompanion.insert(
          word: 'apple',
          meaningVi: 'quả táo',
          createdAt: DateTime.now(),
        ),
      );

      final found1 = await db.findWordByText('apple');
      expect(found1, isNotNull);

      final found2 = await db.findWordByText('Apple');
      expect(found2, isNotNull);

      final found3 = await db.findWordByText('  APPLE  ');
      expect(found3, isNotNull);

      final notFound = await db.findWordByText('banana');
      expect(notFound, isNull);
    });

    test('cascade delete removes word and its review', () async {
      final wordId = await db.insertWordWithReview(
        wordCompanion: WordsCompanion.insert(
          word: 'transient',
          meaningVi: 'ngắn ngủi, tạm thời',
          createdAt: DateTime.now(),
        ),
      );

      expect(await db.getWordById(wordId), isNotNull);
      expect(await db.getReviewForWord(wordId), isNotNull);

      await db.deleteWord(wordId);

      expect(await db.getWordById(wordId), isNull);
      expect(await db.getReviewForWord(wordId), isNull);
    });

    test('watchWords filters by search query and tags', () async {
      await db.insertWordWithReview(
        wordCompanion: WordsCompanion.insert(
          word: 'diligent',
          meaningVi: 'chăm chỉ, cần cù',
          tags: const Value(',ielts,personality,'),
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );

      await db.insertWordWithReview(
        wordCompanion: WordsCompanion.insert(
          word: 'ephemeral',
          meaningVi: 'chóng tàn, phù du',
          tags: const Value(',c2,advanced,'),
          createdAt: DateTime.now(),
        ),
      );

      // Search by word
      final wordsQuery = await db.watchWords(searchQuery: 'dili').first;
      expect(wordsQuery.length, equals(1));
      expect(wordsQuery.first.word, equals('diligent'));

      // Search by Vietnamese meaning
      final viQuery = await db.watchWords(searchQuery: 'phù du').first;
      expect(viQuery.length, equals(1));
      expect(viQuery.first.word, equals('ephemeral'));

      // Filter by tag
      final tagQuery = await db.watchWords(tagFilter: 'ielts').first;
      expect(tagQuery.length, equals(1));
      expect(tagQuery.first.word, equals('diligent'));

      final tagQuery2 = await db.watchWords(tagFilter: '#c2').first;
      expect(tagQuery2.length, equals(1));
      expect(tagQuery2.first.word, equals('ephemeral'));
    });

    test('watchDueWords and updateReviewAndLog update review and create log', () async {
      final now = DateTime.now();
      final wordId = await db.insertWordWithReview(
        wordCompanion: WordsCompanion.insert(
          word: 'persistent',
          meaningVi: 'kiên trì',
          createdAt: now,
        ),
        dueDate: now.subtract(const Duration(hours: 1)), // Due today
      );

      final dueWords = await db.getDueWords();
      expect(dueWords.any((w) => w.word.id == wordId), isTrue);

      final sm2Result = Sm2.calculate(
        interval: 0,
        easeFactor: 2.5,
        repetitions: 0,
        lapses: 0,
        grade: Sm2.gradeGood,
        today: now,
      );

      await db.updateReviewAndLog(
        wordId: wordId,
        grade: Sm2.gradeGood,
        sm2Result: sm2Result,
      );

      final updatedReview = await db.getReviewForWord(wordId);
      expect(updatedReview!.interval, equals(1));
      expect(updatedReview.repetitions, equals(1));

      // Review logs should have 1 entry
      final logs = await db.select(db.reviewLogs).get();
      expect(logs.length, equals(1));
      expect(logs.first.wordId, equals(wordId));
      expect(logs.first.grade, equals(Sm2.gradeGood));
    });

    test('statistics and widget queries work as expected', () async {
      final now = DateTime.now();

      // Word 1: in learning (repetitions > 0, interval < 21)
      final word1Id = await db.insertWordWithReview(
        wordCompanion: WordsCompanion.insert(
          word: 'learning_word',
          meaningVi: 'từ đang học',
          createdAt: now,
        ),
      );
      await (db.update(db.reviews)..where((t) => t.wordId.equals(word1Id))).write(
        const ReviewsCompanion(
          repetitions: Value(2),
          interval: Value(6),
        ),
      );

      // Word 2: mastered (interval >= 21)
      final word2Id = await db.insertWordWithReview(
        wordCompanion: WordsCompanion.insert(
          word: 'mastered_word',
          meaningVi: 'từ thành thạo',
          createdAt: now,
        ),
      );
      await (db.update(db.reviews)..where((t) => t.wordId.equals(word2Id))).write(
        const ReviewsCompanion(
          repetitions: Value(5),
          interval: Value(25),
        ),
      );

      // Total words
      expect(await db.getTotalWordsCount(), equals(2));

      // Mastered words
      expect(await db.getMasteredWordsCount(), equals(1));

      // Widget word prioritizes learning word
      final widgetWord = await db.getWordForWidget();
      expect(widgetWord, isNotNull);
      expect(widgetWord!.word, equals('learning_word'));

      // Streak calculation with review logs
      await db.into(db.reviewLogs).insert(
            ReviewLogsCompanion.insert(
              wordId: word1Id,
              grade: 4,
              reviewedAt: now,
            ),
          );
      await db.into(db.reviewLogs).insert(
            ReviewLogsCompanion.insert(
              wordId: word2Id,
              grade: 5,
              reviewedAt: now.subtract(const Duration(days: 1)),
            ),
          );

      expect(await db.calculateStreak(), equals(2));
    });
  });
}
