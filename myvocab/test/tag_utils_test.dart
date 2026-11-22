import 'package:flutter_test/flutter_test.dart';
import 'package:myvocab/utils/tag_utils.dart';

void main() {
  group('TagUtils Tests', () {
    test('normalize tags correctly', () {
      expect(TagUtils.normalize('ielts, food, verbs'), equals(',ielts,food,verbs,'));
      expect(TagUtils.normalize('#ielts, #travel'), equals(',ielts,travel,'));
      expect(TagUtils.normalize('  ielts  ,   DAILY  '), equals(',ielts,daily,'));
      expect(TagUtils.normalize(''), isNull);
      expect(TagUtils.normalize(null), isNull);
      expect(TagUtils.normalize('   '), isNull);
    });

    test('formatForDisplay formats normalized tags for display', () {
      expect(TagUtils.formatForDisplay(',ielts,food,'), equals('ielts, food'));
      expect(TagUtils.formatForDisplay(''), equals(''));
      expect(TagUtils.formatForDisplay(null), equals(''));
    });

    test('toList converts normalized tags to a list of tags', () {
      expect(TagUtils.toList(',ielts,food,'), equals(['ielts', 'food']));
      expect(TagUtils.toList(''), isEmpty);
      expect(TagUtils.toList(null), isEmpty);
    });
  });
}
