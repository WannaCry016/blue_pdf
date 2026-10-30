import 'package:blue_pdf/pdf/page_ranges.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsePageRanges', () {
    test('converts 1-based ranges to 0-based indices', () {
      expect(parsePageRanges('1-3', 10), [0, 1, 2]);
      expect(parsePageRanges('7', 10), [6]);
    });

    test('keeps the order the user typed', () {
      expect(parsePageRanges('9-10, 1, 4-5', 10), [8, 9, 0, 3, 4]);
    });

    test('drops repeated pages after their first appearance', () {
      expect(parsePageRanges('2-4, 3, 1-2', 10), [1, 2, 3, 0]);
    });

    test('tolerates spaces and stray commas', () {
      expect(parsePageRanges(' 1 - 2 ,, 5 ,', 5), [0, 1, 4]);
    });

    test('accepts the last page', () {
      expect(parsePageRanges('1-5', 5), [0, 1, 2, 3, 4]);
    });

    test('rejects empty input', () {
      expect(() => parsePageRanges('  ,  ', 5), throwsFormatException);
    });

    test('rejects pages past the end with the page count', () {
      expect(
        () => parsePageRanges('4-6', 5),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', 'This PDF has 5 pages')),
      );
      expect(
        () => parsePageRanges('2', 1),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', 'This PDF has 1 page')),
      );
    });

    test('rejects page zero', () {
      expect(() => parsePageRanges('0-2', 5), throwsFormatException);
    });

    test('rejects backwards ranges and suggests the fix', () {
      expect(
        () => parsePageRanges('5-2', 5),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('2-5'))),
      );
    });

    test('rejects text that is not a page or range', () {
      for (final input in ['abc', '1-', '-3', '1-2-3', '2.5']) {
        expect(() => parsePageRanges(input, 5), throwsFormatException, reason: input);
      }
    });
  });
}
