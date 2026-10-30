import 'package:blue_pdf/screens/about_page.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AboutPage', () {
    setUp(() => PackageInfo.setMockInitialValues(
          appName: 'Blue PDF',
          packageName: 'com.bluepdf.blue_pdf',
          version: '2.0.0',
          buildNumber: '5',
          buildSignature: '',
        ));

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
      final prefs = await SharedPreferences.getInstance();
      expect(ThemePrefs.themeModeFrom(prefs), ThemeMode.light);
    });

    test('round-trips every theme mode', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      for (final mode in ThemeMode.values) {
        await ThemePrefs.saveThemeMode(mode);
        expect(ThemePrefs.themeModeFrom(prefs), mode);
      }
    });
  });
}
