class Sm2Result {
  final int interval;
  final double easeFactor;
  final int repetitions;
  final int lapses;
  final DateTime dueDate;

  const Sm2Result({
    required this.interval,
    required this.easeFactor,
    required this.repetitions,
    required this.lapses,
    required this.dueDate,
  });

  @override
  String toString() {
    return 'Sm2Result(interval: $interval, easeFactor: $easeFactor, reps: $repetitions, lapses: $lapses, dueDate: $dueDate)';
  }
}

class Sm2 {
  static const double minEaseFactor = 1.3;

  /// Grades: Quên = 1, Mơ hồ = 3, Nhớ = 4, Dễ = 5.
  static const int gradeAgain = 1;
  static const int gradeHard = 3;
  static const int gradeGood = 4;
  static const int gradeEasy = 5;

  /// Calculates next SM-2 interval, easeFactor, repetitions, lapses, and dueDate.
  static Sm2Result calculate({
    required int interval,
    required double easeFactor,
    required int repetitions,
    required int lapses,
    required int grade,
    DateTime? today,
  }) {
    final baseDate = today ?? DateTime.now();
    int newInterval;
    double newEaseFactor = easeFactor;
    int newRepetitions = repetitions;
    int newLapses = lapses;

    if (grade >= 3) {
      if (repetitions == 0) {
        newInterval = 1;
      } else if (repetitions == 1) {
        newInterval = 6;
      } else {
        newInterval = (interval * easeFactor).round();
      }
      newRepetitions = repetitions + 1;
      newEaseFactor = easeFactor + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02));
      if (newEaseFactor < minEaseFactor) {
        newEaseFactor = minEaseFactor;
      }
    } else {
      // Grade == 1 (Quên)
      newRepetitions = 0;
      newInterval = 1;
      newLapses = lapses + 1;
      if (newEaseFactor < minEaseFactor) {
        newEaseFactor = minEaseFactor;
      }
    }

    // Clean up precision to 4 decimal places
    newEaseFactor = double.parse(newEaseFactor.toStringAsFixed(4));

    final newDueDate = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
    ).add(Duration(days: newInterval));

    return Sm2Result(
      interval: newInterval,
      easeFactor: newEaseFactor,
      repetitions: newRepetitions,
      lapses: newLapses,
      dueDate: newDueDate,
    );
  }
}
