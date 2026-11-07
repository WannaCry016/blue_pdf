import 'dart:io';

import 'package:blue_pdf/components/empty_state_card.dart';
import 'package:blue_pdf/components/pdf_password_dialog.dart';
import 'package:blue_pdf/components/privacy_policy_page.dart';
import 'package:blue_pdf/components/save_pdf.dart';
import 'package:blue_pdf/components/set_password_dialog.dart';
import 'package:blue_pdf/components/split_view.dart';
import 'package:blue_pdf/pdf/pdf_engine.dart';
import 'package:blue_pdf/screens/about_page.dart';
import 'package:blue_pdf/screens/home_screen.dart';
import 'package:blue_pdf/screens/process_success_screen.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Logical sizes of the devices people use, portrait first.
const _devices = {
  'small phone': Size(320, 640),
  'compact phone': Size(360, 640),
  'common Android': Size(360, 800),
  'Fold cover screen': Size(344, 882),
  'Pixel / iPhone': Size(393, 852),
  'large phone': Size(412, 915),
  'Fold open': Size(690, 830),
  'tablet': Size(800, 1280),
};

// Tests draw text in a font of full-width squares by default, which overflows where
// real text doesn't. Load the Roboto and Material Icons that ship with the Flutter SDK.
Future<void> _loadRealFonts() async {
  final fonts = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async => ByteData.sublistView(await File('$fonts/$name').readAsBytes());
  // 'sans-serif' is Roboto on Android; the brand title asks for it by that name.
  for (final family in ['Roboto', 'sans-serif']) {
    final loader = FontLoader(family);
    for (final weight in ['regular', 'medium', 'bold', 'light', 'black']) {
      loader.addFont(read('roboto-$weight.ttf'));
    }
    await loader.load();
  }
  await (FontLoader('MaterialIcons')..addFont(read('materialicons-regular.otf'))).load();
}

void main() {
  setUpAll(_loadRealFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> show(WidgetTester tester, Size size, {double textScale = 1, Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: ThemeData(brightness: brightness, useMaterial3: true),
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: const HomeScreen(),
        ),
      ),
    ));
    await tester.pump();
  }

  for (final MapEntry(key: name, value: size) in _devices.entries) {
    for (final landscape in [false, true]) {
      final screen = landscape ? size.flipped : size;
      final label = '$name ${landscape ? 'landscape' : 'portrait'} (${screen.width.toInt()}x${screen.height.toInt()})';

      testWidgets('home fits on $label', (tester) async {
        await show(tester, screen);
        expect(tester.takeException(), isNull);
        expect(find.text('Select File'), findsOneWidget);
      });

      testWidgets('home fits on $label with large text', (tester) async {
        await show(tester, screen, textScale: 1.3, brightness: Brightness.dark);
        expect(tester.takeException(), isNull);
      });
    }
  }

  group('other screens and dialogs', () {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('screen_sizes_test');
      messenger.setMockMethodCallHandler(PdfEngine.channel, (call) async => switch (call.method) {
            'canSaveToDownloads' => true,
            'describeSaved' => {'name': 'Quarterly report for the finance team (final).pdf', 'size': 2516582},
            'renderPage' => throw PlatformException(code: 'NO_ENGINE'),
            _ => null,
          });
    });
    tearDown(() {
      messenger.setMockMethodCallHandler(PdfEngine.channel, null);
      dir.deleteSync(recursive: true);
    });

    /// Opens [open] from a blank screen on [screen], optionally with the keyboard up.
    Future<void> openOn(WidgetTester tester, Size screen, void Function(BuildContext) open,
        {double textScale = 1, bool keyboard = false}) async {
      tester.view.physicalSize = screen * 3;
      tester.view.devicePixelRatio = 3;
      if (keyboard) tester.view.viewInsets = const FakeViewPadding(bottom: 280 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: Builder(
              builder: (context) => Scaffold(body: TextButton(onPressed: () => open(context), child: const Text('open'))),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    final screens = <String, void Function(BuildContext, Directory)>{
      'About': (context, _) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AboutPage())),
      'Privacy policy': (context, _) =>
          Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyPage())),
      'success screen': (context, _) => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ProcessSuccessScreen(
                saved: SavedPdf(
                  location: 'content://media/external/downloads/42',
                  localPath: '/cache/outputs/report.pdf',
                  fileName: 'Quarterly report for the finance team (final).pdf',
                  folder: 'Download/BLUE PDF',
                ),
              ),
            ),
          ),
      'save sheet': (context, dir) {
        final source = File('${dir.path}/merged.pdf')..writeAsStringSync('%PDF');
        SavePdfOverlay.show(context, sourcePath: source.path, next: (_) => const SizedBox());
      },
      'split dialog': (context, _) =>
          SplitPdfDialog.show(context, const SelectedFile(name: 'a.pdf', path: '/a.pdf'), 248),
      'set password dialog': (context, _) => showSetPasswordDialog(context),
      'unlock PDF dialog': (context, _) => showPdfPasswordDialog(
            context,
            fileName: 'Quarterly report for the finance team (final).pdf',
            verify: (_) async => true,
          ),
    };
    const withKeyboard = {'save sheet', 'split dialog', 'set password dialog', 'unlock PDF dialog'};

    for (final MapEntry(key: screenName, value: open) in screens.entries) {
      for (final MapEntry(key: device, value: size) in _devices.entries) {
        testWidgets('$screenName fits on $device', (tester) async {
          await openOn(tester, size, (context) => open(context, dir));
          expect(tester.takeException(), isNull);
        });

        testWidgets('$screenName fits on $device with large text', (tester) async {
          await openOn(tester, size, (context) => open(context, dir), textScale: 1.3);
          expect(tester.takeException(), isNull);
        });

        if (withKeyboard.contains(screenName)) {
          testWidgets('$screenName fits on $device with the keyboard open', (tester) async {
            await openOn(tester, size, (context) => open(context, dir), keyboard: true);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  testWidgets('the empty card shows the illustration on a normal phone', (tester) async {
    await show(tester, _devices['common Android']!);
    expect(find.descendant(of: find.byType(EmptyStateCard), matching: find.byType(Image)), findsOneWidget);
    expect(find.text(EmptyStateCard.message), findsOneWidget);
  });

  testWidgets('the empty card drops what does not fit instead of squashing it', (tester) async {
    await show(tester, _devices['common Android']!.flipped);
    expect(find.descendant(of: find.byType(EmptyStateCard), matching: find.byType(Image)), findsNothing);
  });
}
