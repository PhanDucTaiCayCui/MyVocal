import 'package:flutter_test/flutter_test.dart';
import 'package:myvocab/services/dictionary_service.dart';

void main() {
  group('DictionaryService Tests', () {
    test('DictionaryResult stores translations and suggestions', () {
      const result = DictionaryResult(
        word: 'resilience',
        phonetic: '/rɪˈzɪl.jəns/',
        partOfSpeech: 'noun',
        example: 'She showed great resilience.',
        definitions: ['The capacity to recover quickly from difficulties.'],
        meaningVi: 'sự kiên cường',
        exampleVi: 'Cô ấy đã thể hiện sự kiên cường tuyệt vời.',
        vietnameseMeanings: ['sự kiên cường', 'khả năng phục hồi', 'tính đàn hồi'],
      );

      expect(result.word, equals('resilience'));
      expect(result.phonetic, equals('/rɪˈzɪl.jəns/'));
      expect(result.partOfSpeech, equals('noun'));
      expect(result.meaningVi, equals('sự kiên cường'));
      expect(result.exampleVi, equals('Cô ấy đã thể hiện sự kiên cường tuyệt vời.'));
      expect(result.vietnameseMeanings.length, equals(3));
      expect(result.vietnameseMeanings, contains('khả năng phục hồi'));
    });
  });
}
