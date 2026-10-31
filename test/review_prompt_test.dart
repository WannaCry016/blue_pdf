import 'package:blue_pdf/services/review_prompt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReviewPrompt.shouldAsk', () {
    final start = DateTime(2026, 1, 1);

    bool ask({required Duration sinceFirst, required int saves, int timesAsked = 0, Duration? sinceAsked}) {
      final now = start.add(sinceFirst);
      return ReviewPrompt.shouldAsk(
        now: now,
        savesSinceAsk: saves,
        timesAsked: timesAsked,
        firstSave: start,
        lastAsked: sinceAsked == null ? null : now.subtract(sinceAsked),
      );
    }

    test('first ask needs three saves and a day since the first', () {
      expect(ask(sinceFirst: const Duration(days: 2), saves: 2), isFalse);
      expect(ask(sinceFirst: const Duration(hours: 5), saves: 10), isFalse, reason: 'still the first session');
      expect(ask(sinceFirst: const Duration(days: 1), saves: 3), isTrue);
    });

    test('later asks wait 30 days and two more saves', () {
      expect(
        ask(sinceFirst: const Duration(days: 90), saves: 5, timesAsked: 1, sinceAsked: const Duration(days: 29)),
        isFalse,
      );
      expect(
        ask(sinceFirst: const Duration(days: 90), saves: 1, timesAsked: 1, sinceAsked: const Duration(days: 40)),
        isFalse,
      );
      expect(
        ask(sinceFirst: const Duration(days: 90), saves: 2, timesAsked: 1, sinceAsked: const Duration(days: 30)),
        isTrue,
      );
    });

    test('stops after four asks', () {
      expect(
        ask(sinceFirst: const Duration(days: 400), saves: 9, timesAsked: 4, sinceAsked: const Duration(days: 90)),
        isFalse,
      );
    });
  });

  group('ReviewPrompt.onSuccessfulSave', () {
    late DateTime now;
    late int requests;
    late bool available;
    late ReviewPrompt prompt;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      now = DateTime(2026, 1, 1, 10);
      requests = 0;
      available = true;
      prompt = ReviewPrompt(
        isAvailable: () async => available,
        requestReview: () async => requests++,
        now: () => now,
        delay: Duration.zero,
      );
    });

    Future<void> save({bool visible = true}) => prompt.onSuccessfulSave(stillVisible: () => visible);

    test('asks on a later day once there are three saves, then not again for a month', () async {
      await save();
      await save();
      await save();
      expect(requests, 0, reason: 'all in the first session');

      now = now.add(const Duration(days: 1));
      await save();
      expect(requests, 1);

      now = now.add(const Duration(days: 10));
      await save();
      await save();
      expect(requests, 1);

      now = now.add(const Duration(days: 25));
      await save();
      expect(requests, 2, reason: 'two saves since the last ask, over 30 days later');
    });

    test('keeps the chance when the user already left the screen', () async {
      for (var i = 0; i < 3; i++) {
        await save();
      }
      now = now.add(const Duration(days: 2));
      await save(visible: false);
      expect(requests, 0);

      await save();
      expect(requests, 1);
    });

    test('does nothing when Play reviews are unavailable', () async {
      available = false;
      now = now.subtract(const Duration(days: 5));
      for (var i = 0; i < 3; i++) {
        await save();
      }
      now = now.add(const Duration(days: 5));
      await save();
      expect(requests, 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('review_times_asked'), isNull);
    });

    test('a failing review call never throws', () async {
      prompt = ReviewPrompt(
        isAvailable: () async => true,
        requestReview: () async => throw Exception('Play unavailable'),
        now: () => now,
        delay: Duration.zero,
      );
      for (var i = 0; i < 3; i++) {
        await save();
      }
      now = now.add(const Duration(days: 2));
      await expectLater(save(), completes);
    });
  });
}
