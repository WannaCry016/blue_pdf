import 'dart:io';

import 'package:blue_pdf/components/save_pdf.dart';
import 'package:blue_pdf/pdf/pdf_engine.dart';
import 'package:blue_pdf/utils/pdf_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSaver extends PdfSaver {
  final calls = <String>[];
  String? pickerResult = 'content://picked/doc';
  String? initialDirectory;

  @override
  Future<String?> saveToAppFolder({required String name, required String sourcePath}) async {
    calls.add('appFolder:$name');
    return 'content://media/external/downloads/7';
  }

  @override
  Future<String?> saveWithPicker({required String name, required String sourcePath, String? initialDirectory}) async {
    calls.add('picker:$name');
    this.initialDirectory = initialDirectory;
    return pickerResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory dir;
  late _FakeSaver saver;
  late bool canSaveToDownloads;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('save_pdf_test');
    saver = _FakeSaver();
    canSaveToDownloads = true;
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(PdfEngine.channel, (call) async {
      if (call.method == 'canSaveToDownloads') return canSaveToDownloads;
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(PdfEngine.channel, null);
    dir.deleteSync(recursive: true);
  });

  /// Opens the sheet from a home screen and returns a getter for its result.
  Future<SavedPdf? Function()> openSheet(WidgetTester tester) async {
    final source = File('${dir.path}/merged.pdf')..writeAsStringSync('%PDF');
    SavedPdf? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await SavePdfOverlay.show(
                  context,
                  sourcePath: source.path,
                  saver: saver,
                  next: (saved) => Scaffold(body: Text('Saved ${saved.fileName} to ${saved.folder}')),
                );
              },
              child: const Text('home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    return () => result;
  }

  Future<void> enterName(WidgetTester tester, String name) => tester.enterText(find.byType(TextField), name);

  /// Saving renames a real file, which needs real async.
  Future<void> tapAndWait(WidgetTester tester, String label) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(label));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('saves straight to the app folder by default, with no picker', (tester) async {
    final result = await openSheet(tester);
    expect(find.text('Save to Download/BLUE PDF'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isTrue);

    await enterName(tester, 'Invoices');
    await tapAndWait(tester, 'Save');

    expect(saver.calls, ['appFolder:Invoices']);
    expect(find.text('Saved Invoices.pdf to Download/BLUE PDF'), findsOneWidget);
    expect(find.byType(SavePdfOverlay), findsNothing);
    expect(result()?.location, 'content://media/external/downloads/7');
    expect(File('${dir.path}/Invoices.pdf').existsSync(), isTrue);
  });

  testWidgets('opting out goes through the picker and is remembered', (tester) async {
    SharedPreferences.setMockInitialValues({'last_save_location': 'content://picked/earlier'});
    await openSheet(tester);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(find.text('Choose folder'), findsOneWidget);

    await tapAndWait(tester, 'Choose folder');
    expect(saver.calls.single, startsWith('picker:'));
    expect(saver.initialDirectory, 'content://picked/earlier');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('save_to_app_folder'), isFalse);
    expect(prefs.getString('last_save_location'), 'content://picked/doc');
  });

  testWidgets('backing out of the picker keeps the sheet open', (tester) async {
    SharedPreferences.setMockInitialValues({'save_to_app_folder': false});
    saver.pickerResult = null;
    final result = await openSheet(tester);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isFalse);

    await tapAndWait(tester, 'Choose folder');

    expect(find.byType(SavePdfOverlay), findsOneWidget);
    expect(find.text('Choose folder'), findsOneWidget);
    expect(result(), isNull);
  });

  testWidgets('without scoped storage there is no option and Save opens the picker', (tester) async {
    canSaveToDownloads = false;
    await openSheet(tester);
    expect(find.byType(CheckboxListTile), findsNothing);

    await tapAndWait(tester, 'Save');

    expect(saver.calls.single, startsWith('picker:'));
    expect(find.textContaining('Saved bluepdf_'), findsOneWidget);
  });

  testWidgets('Cancel completes with null', (tester) async {
    final result = await openSheet(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(SavePdfOverlay), findsNothing);
    expect(result(), isNull);
    expect(saver.calls, isEmpty);
  });

  test('canSaveToDownloads falls back to false when the platform cannot say', () async {
    messenger.setMockMethodCallHandler(PdfEngine.channel, (_) async => throw PlatformException(code: 'X'));
    expect(await PdfEngine.canSaveToDownloads(), isFalse);
  });
}
