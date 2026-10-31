import 'package:blue_pdf/components/save_pdf.dart';
import 'package:blue_pdf/pdf/pdf_engine.dart';
import 'package:blue_pdf/screens/process_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  const saved = SavedPdf(
    location: 'content://media/external/downloads/42',
    localPath: '/cache/outputs/Report.pdf',
    fileName: 'Report.pdf',
    folder: 'Download/BLUE PDF',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(PdfEngine.channel, (call) async {
      if (call.method == 'describeSaved') return {'name': 'Report (1).pdf', 'size': 2516582};
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(PdfEngine.channel, null));

  Future<void> show(WidgetTester tester, Brightness brightness) async {
    // A small phone, so anything that overflows shows up.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ProcessSuccessScreen(saved: saved)),
                  ),
                  child: const Text('home'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('shows the saved file with its real name, size and folder ($brightness)', (tester) async {
      await show(tester, brightness);

      expect(find.text('PDF saved'), findsOneWidget);
      expect(find.text('Report (1).pdf'), findsOneWidget);
      expect(find.text('2.4 MB'), findsOneWidget);
      expect(find.text('Download/BLUE PDF'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Back to home'), findsOneWidget);
    });
  }

  testWidgets('Back to home returns to the first screen', (tester) async {
    await show(tester, Brightness.light);

    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();

    expect(find.byType(ProcessSuccessScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('appears fully at once when animations are turned off', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await show(tester, Brightness.light);

    final fades = tester.widgetList<FadeTransition>(
      find.descendant(of: find.byType(ProcessSuccessScreen), matching: find.byType(FadeTransition)),
    );
    expect(fades.map((f) => f.opacity.value), everyElement(1.0));
  });
}
