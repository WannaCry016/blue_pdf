import 'package:blue_pdf/screens/about_page.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AboutPage', () {
    for (final brightness in Brightness.values) {
      testWidgets('renders in ${brightness.name} mode', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const AboutPage(),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AboutPage), findsOneWidget);
      });
    }
  });

  group('ThemePrefs', () {
    test('defaults to light when nothing is saved', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ThemePrefs.loadThemeMode(), ThemeMode.light);
    });

    test('round-trips every theme mode', () async {
      SharedPreferences.setMockInitialValues({});
      for (final mode in ThemeMode.values) {
        await ThemePrefs.saveThemeMode(mode);
        expect(await ThemePrefs.loadThemeMode(), mode);
      }
    });
  });
}
