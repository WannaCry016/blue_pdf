import 'package:blue_pdf/components/privacy_policy_page.dart';
import 'package:blue_pdf/screens/about_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'BLUE PDF',
      packageName: 'com.bluepdf.blue_pdf',
      version: '1.0.3',
      buildNumber: '22',
      buildSignature: '',
    );
  });

  Future<void> show(WidgetTester tester, Widget page, Brightness brightness) async {
    // A small phone, so anything that overflows shows up.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: brightness), home: page));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets('About shows the version without the build number ($brightness)', (tester) async {
      await show(tester, const AboutPage(), brightness);

      expect(find.text('Version 1.0.3'), findsOneWidget);
      expect(find.text('Connect'), findsNothing);
      expect(find.text('GitHub'), findsNothing);
      final avatar = tester.widget<Image>(find.byType(Image));
      expect(((avatar.image as ResizeImage).imageProvider as AssetImage).assetName, 'assets/avatar.webp');
      expect(find.byIcon(Icons.person), findsNothing);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('Privacy Policy lists every section and the contact ($brightness)', (tester) async {
      await show(tester, const PrivacyPolicyPage(), brightness);

      // The header gradient must fill the app bar, like every other screen.
      final gradient = find.descendant(
        of: find.byType(AppBar),
        matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration),
      );
      expect(tester.getSize(gradient), tester.getSize(find.byType(AppBar)));

      expect(find.text('Private by design'), findsOneWidget);
      expect(find.text('Last updated ${PrivacyPolicyPage.lastUpdated}'), findsOneWidget);
      await tester.scrollUntilVisible(find.text(PrivacyPolicyPage.contactEmail), 300);
      expect(find.text('Changes to this policy'), findsOneWidget);
      expect(find.text(PrivacyPolicyPage.contactEmail), findsOneWidget);
    });
  }
}
