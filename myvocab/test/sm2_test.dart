import 'package:flutter_test/flutter_test.dart';
import 'package:myvocab/domain/sm2.dart';

void main() {
  group('SM-2 Algorithm Tests', () {
    final testDate = DateTime(2026, 11, 22);

    test('Grade 1 (Quên) resets repetitions and interval, increments lapses', () {
      final result = Sm2.calculate(
        interval: 10,
        easeFactor: 2.5,
        repetitions: 3,
        lapses: 0,
        grade: Sm2.gradeAgain,
        today: testDate,
      );

      expect(result.interval, equals(1));
      expect(result.repetitions, equals(0));
      expect(result.lapses, equals(1));
      expect(result.easeFactor, equals(2.5));
      expect(result.dueDate, equals(testDate.add(const Duration(days: 1))));
    });

    test('Grade 3 (Mơ hồ) - repetitions == 0 -> interval = 1, easeFactor reduces by 0.14', () {
      final result = Sm2.calculate(
        interval: 0,
        easeFactor: 2.5,
        repetitions: 0,
        lapses: 0,
        grade: Sm2.gradeHard,
        today: testDate,
      );

      expect(result.interval, equals(1));
      expect(result.repetitions, equals(1));
      expect(result.lapses, equals(0));
      expect(result.easeFactor, closeTo(2.36, 0.0001));
      expect(result.dueDate, equals(testDate.add(const Duration(days: 1))));
    });

    test('Grade 4 (Nhớ) - repetitions == 1 -> interval = 6, easeFactor unchanged', () {
      final result = Sm2.calculate(
        interval: 1,
        easeFactor: 2.5,
        repetitions: 1,
        lapses: 0,
        grade: Sm2.gradeGood,
        today: testDate,
      );

      expect(result.interval, equals(6));
      expect(result.repetitions, equals(2));
      expect(result.lapses, equals(0));
      expect(result.easeFactor, equals(2.5));
      expect(result.dueDate, equals(testDate.add(const Duration(days: 6))));
    });

    test('Grade 5 (Dễ) - repetitions > 1 -> interval = (interval * easeFactor).round(), easeFactor increases by 0.1', () {
      final result = Sm2.calculate(
        interval: 6,
        easeFactor: 2.5,
        repetitions: 2,
        lapses: 0,
        grade: Sm2.gradeEasy,
        today: testDate,
      );

      expect(result.interval, equals(15)); // 6 * 2.5 = 15
      expect(result.repetitions, equals(3));
      expect(result.lapses, equals(0));
      expect(result.easeFactor, equals(2.6));
      expect(result.dueDate, equals(testDate.add(const Duration(days: 15))));
    });

    test('easeFactor never falls below minimum floor 1.3', () {
      final result = Sm2.calculate(
        interval: 1,
        easeFactor: 1.35,
        repetitions: 1,
        lapses: 0,
        grade: Sm2.gradeHard, // 1.35 - 0.14 = 1.21 < 1.3
        today: testDate,
      );

      expect(result.easeFactor, equals(1.3));
    });

    test('Grade 1 with low easeFactor also respects minimum floor 1.3', () {
      final result = Sm2.calculate(
        interval: 5,
        easeFactor: 1.2,
        repetitions: 2,
        lapses: 1,
        grade: Sm2.gradeAgain,
        today: testDate,
      );

      expect(result.easeFactor, equals(1.3));
    });
  });
}
