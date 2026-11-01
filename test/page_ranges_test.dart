import 'package:blue_pdf/components/split_view.dart';
import 'package:blue_pdf/pdf/page_ranges.dart';
import 'package:blue_pdf/pdf/pdf_engine.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PageRange', () {
    test('converts a 1-based range to 0-based indices', () {
      expect(PageRange('2', '4', 10).pages, [1, 2, 3]);
      expect(PageRange('7', '7', 10).pages, [6]);
      expect(PageRange('1', '5', 5).pages, [0, 1, 2, 3, 4]);
    });

    test('an empty box is unfinished, not an error, and leaves the other box alone', () {
      final range = PageRange('', '4', 10);
      expect(range.isValid, isFalse);
      expect(range.pages, isEmpty);
      expect(range.fromError, isNull);
      expect(range.toError, isNull);
      expect(range.to, 4);
    });

    test('a page past the end only marks its own box', () {
      final range = PageRange('2', '12', 10);
      expect(range.fromError, isNull);
      expect(range.from, 2);
      expect(range.toError, 'Only 10 pages');
      expect(range.to, isNull);
      expect(PageRange('2', '1', 1).fromError, 'Only 1 page');
    });

    test('page zero is rejected', () {
      expect(PageRange('0', '3', 5).fromError, 'Pages start at 1');
    });

    test('a backwards range blames the box edited last', () {
      final editedTo = PageRange('5', '2', 10);
      expect(editedTo.toError, "Can't be before page 5");
      expect(editedTo.fromError, isNull);

      final editedFrom = PageRange('5', '2', 10, editedFrom: true);
      expect(editedFrom.fromError, "Can't be after page 2");
      expect(editedFrom.toError, isNull);

      expect(editedTo.isValid, isFalse);
      expect(editedTo.from, 5);
      expect(editedTo.to, 2);
    });
  });

  group('SplitPdfDialog', () {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    setUp(() => messenger.setMockMethodCallHandler(PdfEngine.channel, (_) async => throw Exception('no engine')));
    tearDown(() => messenger.setMockMethodCallHandler(PdfEngine.channel, null));

    Future<Future<List<int>?>> open(WidgetTester tester) async {
      // A small phone, so anything that overflows shows up.
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      late Future<List<int>?> result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = SplitPdfDialog.show(context, const SelectedFile(name: 'a.pdf', path: '/a.pdf'), 10),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    Future<void> type(WidgetTester tester, String label, String text) async {
      await tester.enterText(find.widgetWithText(TextField, label), text);
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('starts with every page and returns the chosen range', (tester) async {
      final result = await open(tester);
      expect(find.text('10 of 10 pages selected'), findsOneWidget);

      await type(tester, 'From', '3');
      await type(tester, 'To', '5');
      expect(find.text('3 of 10 pages selected'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Split PDF'));
      await tester.pumpAndSettle();
      expect(await result, [2, 3, 4]);
    });

    testWidgets('clearing a box to retype shows no errors', (tester) async {
      await open(tester);
      await type(tester, 'From', '');

      expect(find.textContaining("Can't"), findsNothing);
      expect(find.textContaining('Only'), findsNothing);
      expect(find.text('This PDF has 10 pages'), findsOneWidget);
    });

    testWidgets('a backwards range is flagged on the box being edited', (tester) async {
      await open(tester);
      await type(tester, 'To', '5');
      await type(tester, 'From', '8');

      expect(find.text("Can't be after page 5"), findsOneWidget);
      expect(find.textContaining("Can't be before"), findsNothing);
    });

    testWidgets('a bad page is flagged on its own box only', (tester) async {
      await open(tester);
      await type(tester, 'To', '15');

      expect(find.text('Only 10 pages'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Split PDF'));
      expect(button.onPressed, isNull);
    });
  });
}
