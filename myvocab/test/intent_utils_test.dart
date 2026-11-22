import 'package:flutter_test/flutter_test.dart';
import 'package:myvocab/utils/intent_utils.dart';

void main() {
  group('IntentUtils Tests', () {
    test('cleanSharedText strips punctuation and symbols at both ends', () {
      expect(IntentUtils.cleanSharedText('ubiquitous,'), equals('ubiquitous'));
      expect(IntentUtils.cleanSharedText('"ubiquitous,"'), equals('ubiquitous'));
      expect(IntentUtils.cleanSharedText('(resilience)!'), equals('resilience'));
      expect(IntentUtils.cleanSharedText('  “ephemeral”...  '), equals('ephemeral'));
      expect(IntentUtils.cleanSharedText('#diligent!'), equals('diligent'));
      expect(IntentUtils.cleanSharedText('hello world.'), equals('hello world'));
      expect(IntentUtils.cleanSharedText(''), equals(''));
      expect(IntentUtils.cleanSharedText('...'), equals(''));
    });
  });
}
