import 'package:blue_pdf/components/slide_page_transitions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> sendBack(WidgetTester tester, String method, [double? progress]) async {
    final arguments = progress == null
        ? null
        : <String, Object?>{'touchOffset': <double>[5, 300], 'progress': progress, 'swipeEdge': 0};
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.backGesture.name,
      SystemChannels.backGesture.codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
    await tester.pump();
  }

  Future<void> openDetails(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        platform: TargetPlatform.android,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {TargetPlatform.android: SlidePageTransitionsBuilder()},
        ),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Center(child: Text('details')))),
            ),
            child: const Text('home'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  Rect detailsPage(WidgetTester tester) =>
      tester.getRect(find.ancestor(of: find.text('details'), matching: find.byType(Scaffold)));

  testWidgets('the back gesture slides the page right at full size and pops it', (tester) async {
    await openDetails(tester);
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;

    await sendBack(tester, 'startBackGesture', 0);
    await sendBack(tester, 'updateBackGestureProgress', 0.5);
    final page = detailsPage(tester);
    expect(page.left, moreOrLessEquals(width / 2, epsilon: 1));
    expect(page.width, width, reason: 'the page must not shrink');
    expect(find.text('home'), findsOneWidget, reason: 'the page beneath shows through');

    await sendBack(tester, 'commitBackGesture');
    await tester.pump(const Duration(milliseconds: 16));
    expect(detailsPage(tester).left, greaterThan(width / 2), reason: 'continues from the finger, no snap back');

    // Half the page was left to go: half the 200 ms transition.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('details'), findsNothing);
    final homeWhenDone = tester.getTopLeft(find.text('home'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('home')), homeWhenDone, reason: 'nothing is still sliding');
  });

  testWidgets('cancelling the back gesture slides the page back', (tester) async {
    await openDetails(tester);

    await sendBack(tester, 'startBackGesture', 0);
    await sendBack(tester, 'updateBackGestureProgress', 0.3);
    await sendBack(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(detailsPage(tester).left, 0);
    expect(find.text('details'), findsOneWidget);
  });
}
