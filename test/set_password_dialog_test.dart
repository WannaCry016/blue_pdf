import 'package:blue_pdf/components/set_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Opens the dialog and returns a getter for what it completed with.
  Future<String? Function()> open(WidgetTester tester) async {
    String? result = 'not closed';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showSetPasswordDialog(context, fileName: 'invoice.pdf'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  final password = find.widgetWithText(TextField, 'Password');
  final confirm = find.widgetWithText(TextField, 'Confirm password');
  FilledButton protect(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Protect'));

  testWidgets('explains the password and names the file', (tester) async {
    await open(tester);
    expect(find.text('Protect PDF'), findsOneWidget);
    expect(find.textContaining('"invoice.pdf"'), findsOneWidget);
    expect(find.textContaining("can't be recovered"), findsOneWidget);
  });

  testWidgets('Protect stays disabled until both fields are filled', (tester) async {
    await open(tester);
    expect(protect(tester).onPressed, isNull);

    await tester.enterText(password, 'secret');
    await tester.pump();
    expect(protect(tester).onPressed, isNull);

    await tester.enterText(confirm, 's');
    await tester.pump();
    expect(protect(tester).onPressed, isNotNull);
  });

  testWidgets('matching passwords return the password', (tester) async {
    final result = await open(tester);
    await tester.enterText(password, 'p@ss word');
    await tester.enterText(confirm, 'p@ss word');
    await tester.pump();
    expect(find.bySemanticsLabel('Passwords match'), findsOneWidget);

    await tester.tap(find.text('Protect'));
    await tester.pumpAndSettle();

    expect(find.byType(SetPasswordDialog), findsNothing);
    expect(result(), 'p@ss word');
  });

  testWidgets('a mismatch is reported only on submit and clears on edit', (tester) async {
    final result = await open(tester);
    await tester.enterText(password, 'secret');
    await tester.enterText(confirm, 'secrte');
    await tester.pump();
    expect(find.text("Passwords don't match"), findsNothing);

    await tester.tap(find.text('Protect'));
    await tester.pump();
    expect(find.text("Passwords don't match"), findsOneWidget);
    expect(find.byType(SetPasswordDialog), findsOneWidget);
    expect(result(), 'not closed');

    await tester.enterText(confirm, 'secret');
    await tester.pump();
    expect(find.text("Passwords don't match"), findsNothing);
  });

  testWidgets('the keyboard moves from password to confirm, then submits', (tester) async {
    final result = await open(tester);
    await tester.enterText(password, 'secret');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(tester.widget<TextField>(confirm).focusNode!.hasFocus, isTrue);

    await tester.enterText(confirm, 'secret');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result(), 'secret');
  });

  testWidgets('one toggle shows and hides both fields', (tester) async {
    await open(tester);
    bool obscured(Finder field) => tester.widget<TextField>(field).obscureText;
    expect(obscured(password) && obscured(confirm), isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(password) || obscured(confirm), isFalse);
  });

  testWidgets('Cancel returns null', (tester) async {
    final result = await open(tester);
    await tester.enterText(password, 'secret');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });
}
