import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/sm2.dart';

part 'database.g.dart';

class WordWithReview {
  final Word word;
  final Review review;

  const WordWithReview({required this.word, required this.review});
}

@DataClassName('Word')
class Words extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text().unique()();
  TextColumn get phonetic => text().nullable()();
  TextColumn get pos => text().nullable()();
  TextColumn get meaningVi => text()();
  TextColumn get example => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get tags => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('Review')
class Reviews extends Table {
  IntColumn get wordId => integer().references(Words, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get interval => integer()();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {wordId};
}

@DataClassName('ReviewLog')
class ReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wordId => integer().references(Words, #id, onDelete: KeyAction.cascade)();
  IntColumn get grade => integer()();
  DateTimeColumn get reviewedAt => dateTime()();
}

@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Words, Reviews, ReviewLogs, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  // Queries for Words
  Stream<List<Word>> watchWords({String? searchQuery, String? tagFilter}) {
    final query = select(words)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final cleanQuery = '%${searchQuery.trim().toLowerCase()}%';
      query.where((t) => t.word.lower().like(cleanQuery) | t.meaningVi.lower().like(cleanQuery));
    }

    if (tagFilter != null && tagFilter.trim().isNotEmpty) {
      final cleanTag = tagFilter.trim().toLowerCase().replaceAll('#', '');
      query.where((t) => t.tags.like('%,$cleanTag,%'));
    }

    return query.watch();
  }

  Future<List<Word>> getAllWords() => select(words).get();

  Future<Word?> getWordById(int id) {
    return (select(words)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Word?> findWordByText(String text, {int? excludeId}) {
    final cleanWord = text.trim().toLowerCase();
    var query = select(words)..where((t) => t.word.equals(cleanWord));
    if (excludeId != null) {
      query = query..where((t) => t.id.equals(excludeId).not());
    }
    return query.getSingleOrNull();
  }

  Future<int> insertWordWithReview({
    required WordsCompanion wordCompanion,
    DateTime? dueDate,
  }) {
    return transaction(() async {
      final wordId = await into(words).insert(wordCompanion);
      final due = dueDate ?? DateTime.now();
      await into(reviews).insert(
        ReviewsCompanion(
          wordId: Value(wordId),
          dueDate: Value(due),
          interval: const Value(0),
          easeFactor: const Value(2.5),
          repetitions: const Value(0),
          lapses: const Value(0),
        ),
      );
      return wordId;
    });
  }

  Future<bool> updateWord(Word word) {
    return update(words).replace(word);
  }

  Future<int> deleteWord(int id) {
    return (delete(words)..where((t) => t.id.equals(id))).go();
  }

  // Reviews queries
  Future<List<Review>> getAllReviews() => select(reviews).get();
  Future<List<ReviewLog>> getAllReviewLogs() => select(reviewLogs).get();

  Future<Review?> getReviewForWord(int wordId) {
    return (select(reviews)..where((t) => t.wordId.equals(wordId))).getSingleOrNull();
  }

  // Home widget query
  Future<Word?> getWordForWidget() async {
    // 1. Prioritize words in learning (repetitions > 0 and interval < 21)
    final learningQuery = select(words).join([
      innerJoin(reviews, reviews.wordId.equalsExp(words.id)),
    ])
      ..where(
        reviews.repetitions.isBiggerThanValue(0) &
            reviews.interval.isSmallerThanValue(21),
      )
      ..orderBy([OrderingTerm.random()])
      ..limit(1);

    final learningRows = await learningQuery.get();
    if (learningRows.isNotEmpty) {
      return learningRows.first.readTable(words);
    }

    // 2. Fallback to any word
    final fallbackQuery = select(words)
      ..orderBy([(t) => OrderingTerm.random()])
      ..limit(1);

    return fallbackQuery.getSingleOrNull();
  }

  // Statistics queries
  Future<int> getTotalWordsCount() async {
    final countExp = words.id.count();
    final row = await (selectOnly(words)..addColumns([countExp])).getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<int> getMasteredWordsCount() async {
    final countExp = reviews.wordId.count();
    final row = await (selectOnly(reviews)
          ..where(reviews.interval.isBiggerOrEqualValue(21))
          ..addColumns([countExp]))
        .getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<int> calculateStreak() async {
    final logs = await select(reviewLogs).get();
    if (logs.isEmpty) return 0;

    final dates = logs.map((l) {
      final d = l.reviewedAt;
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    DateTime checkDate;
    if (dates.contains(today)) {
      checkDate = today;
    } else if (dates.contains(yesterday)) {
      checkDate = yesterday;
    } else {
      return 0;
    }

    int streak = 0;
    while (dates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<Map<DateTime, int>> getReviewCountsLast7Days() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final map = <DateTime, int>{};

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      map[day] = 0;
    }

    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    final logs = await (select(reviewLogs)
          ..where((t) => t.reviewedAt.isBiggerOrEqualValue(sevenDaysAgo)))
        .get();

    for (final log in logs) {
      final logDate = DateTime(
        log.reviewedAt.year,
        log.reviewedAt.month,
        log.reviewedAt.day,
      );
      if (map.containsKey(logDate)) {
        map[logDate] = (map[logDate] ?? 0) + 1;
      }
    }
    return map;
  }

  static DateTime endOfToday([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day, 23, 59, 59, 999);
  }

  Stream<List<WordWithReview>> watchDueWords({DateTime? now}) {
    final end = endOfToday(now);
    final query = select(words).join([
      innerJoin(reviews, reviews.wordId.equalsExp(words.id)),
    ])
      ..where(reviews.dueDate.isSmallerOrEqualValue(end))
      ..orderBy([OrderingTerm.asc(reviews.dueDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return WordWithReview(
          word: row.readTable(words),
          review: row.readTable(reviews),
        );
      }).toList();
    });
  }

  Future<List<WordWithReview>> getDueWords({DateTime? now}) async {
    final end = endOfToday(now);
    final query = select(words).join([
      innerJoin(reviews, reviews.wordId.equalsExp(words.id)),
    ])
      ..where(reviews.dueDate.isSmallerOrEqualValue(end))
      ..orderBy([OrderingTerm.asc(reviews.dueDate)]);

    final rows = await query.get();
    return rows.map((row) {
      return WordWithReview(
        word: row.readTable(words),
        review: row.readTable(reviews),
      );
    }).toList();
  }

  Stream<int> watchDueWordCount({DateTime? now}) {
    final end = endOfToday(now);
    final countExp = words.id.count();
    final query = selectOnly(words)
      ..join([innerJoin(reviews, reviews.wordId.equalsExp(words.id))])
      ..where(reviews.dueDate.isSmallerOrEqualValue(end))
      ..addColumns([countExp]);

    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  Future<void> updateReviewAndLog({
    required int wordId,
    required int grade,
    required Sm2Result sm2Result,
    DateTime? reviewedAt,
  }) {
    return transaction(() async {
      await (update(reviews)..where((t) => t.wordId.equals(wordId))).write(
        ReviewsCompanion(
          interval: Value(sm2Result.interval),
          easeFactor: Value(sm2Result.easeFactor),
          repetitions: Value(sm2Result.repetitions),
          lapses: Value(sm2Result.lapses),
          dueDate: Value(sm2Result.dueDate),
        ),
      );

      await into(reviewLogs).insert(
        ReviewLogsCompanion.insert(
          wordId: wordId,
          grade: grade,
          reviewedAt: reviewedAt ?? DateTime.now(),
        ),
      );
    });
  }

  // Settings queries
  Stream<String?> watchSetting(String key) {
    return (select(settings)..where((t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  // Settings queries
  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) {
    return into(settings).insertOnConflictUpdate(
      Setting(key: key, value: value),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'myvocab.sqlite'));
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
