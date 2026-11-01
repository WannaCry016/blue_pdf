import 'package:blue_pdf/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, {String? version}) => tester.pumpWidget(
        MaterialApp(home: SplashScreen(version: version, next: const Text('home'))),
      );

  testWidgets('shows the logo and app version, then opens the next screen', (tester) async {
    await show(tester, version: '1.0.3');

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Blue PDF • Version v1.0.3'), findsOneWidget);
    expect(find.text('home'), findsNothing);

    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('falls back to the app name without a version', (tester) async {
    await show(tester);

    expect(find.text('Blue PDF'), findsOneWidget);
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
  });
}
