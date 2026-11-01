import 'package:blue_pdf/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, {String? version, Widget next = const Text('home')}) =>
      tester.pumpWidget(MaterialApp(home: SplashScreen(version: version, next: next)));

  testWidgets('covers the next screen with the logo and version, then fades away', (tester) async {
    await show(tester, version: '1.0.3');

    expect(find.text('Blue PDF • Version v1.0.3'), findsOneWidget);
    expect(find.text('home'), findsOneWidget, reason: 'built underneath while the splash shows');

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('Blue PDF • Version v1.0.3'), findsOneWidget, reason: 'held for minVisible');

    await tester.pump(SplashScreen.minVisible);
    await tester.pumpAndSettle();

    expect(find.text('Blue PDF • Version v1.0.3'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('falls back to the app name without a version', (tester) async {
    await show(tester);
    expect(find.text('Blue PDF'), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(SplashScreen.minVisible);
    await tester.pumpAndSettle();
  });

  testWidgets('keeps the next screen\'s state when the splash goes', (tester) async {
    var builds = 0;
    await show(tester, next: _InitCounter(onInit: () => builds++));

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(SplashScreen.minVisible);
    await tester.pumpAndSettle();

    expect(find.text('Blue PDF'), findsNothing);
    expect(find.byType(_InitCounter), findsOneWidget);
    expect(builds, 1);
  });
}

class _InitCounter extends StatefulWidget {
  const _InitCounter({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_InitCounter> createState() => _InitCounterState();
}

class _InitCounterState extends State<_InitCounter> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
