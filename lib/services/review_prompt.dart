import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Asks for a Google Play review at moments the user just got value from the app.
///
/// Play never reveals whether the user rated, or even whether the dialog was
/// shown, and it rate-limits the dialog itself. So this only decides when it
/// is worth asking, and keeps the asks rare:
///
/// - first ask after [firstAskAfterSaves] successful saves, no sooner than a
///   day after the first one, so nobody is asked in their first session
/// - then at most once per [askInterval], after [laterAskAfterSaves] more saves
/// - never more than [maxAsks] times in total
class ReviewPrompt {
  ReviewPrompt({
    Future<bool> Function()? isAvailable,
    Future<void> Function()? requestReview,
    DateTime Function()? now,
    this.delay = const Duration(seconds: 1),
  }) : _isAvailable = isAvailable ?? InAppReview.instance.isAvailable,
       _requestReview = requestReview ?? InAppReview.instance.requestReview,
       _now = now ?? DateTime.now;

  static final instance = ReviewPrompt();

  static const firstAskAfterSaves = 3;
  static const laterAskAfterSaves = 2;
  static const askInterval = Duration(days: 30);
  static const maxAsks = 4;

  static const _firstSaveKey = 'review_first_save_at';
  static const _savesKey = 'review_saves_since_ask';
  static const _lastAskedKey = 'review_last_asked_at';
  static const _timesAskedKey = 'review_times_asked';

  final Future<bool> Function() _isAvailable;
  final Future<void> Function() _requestReview;
  final DateTime Function() _now;

  /// Lets the success screen settle before the review sheet slides over it.
  final Duration delay;

  /// Records a successful save and asks for a review if it is time.
  ///
  /// [stillVisible] is checked after [delay]; when the user has already moved
  /// on, nothing is shown and the chance is kept for a later save.
  Future<void> onSuccessfulSave({required bool Function() stillVisible}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = _now();
      final firstSave = _readTime(prefs, _firstSaveKey);
      if (firstSave == null) await prefs.setInt(_firstSaveKey, now.millisecondsSinceEpoch);
      final saves = (prefs.getInt(_savesKey) ?? 0) + 1;
      await prefs.setInt(_savesKey, saves);
      final timesAsked = prefs.getInt(_timesAskedKey) ?? 0;

      final due = shouldAsk(
        now: now,
        savesSinceAsk: saves,
        timesAsked: timesAsked,
        firstSave: firstSave ?? now,
        lastAsked: _readTime(prefs, _lastAskedKey),
      );
      if (!due) return;

      await Future<void>.delayed(delay);
      if (!stillVisible() || !await _isAvailable()) return;
      await _requestReview();

      await prefs.setInt(_lastAskedKey, now.millisecondsSinceEpoch);
      await prefs.setInt(_timesAskedKey, timesAsked + 1);
      await prefs.setInt(_savesKey, 0);
    } catch (e) {
      // A review prompt must never get in the way of the user's file.
      debugPrint('Review prompt skipped: $e');
    }
  }

  @visibleForTesting
  static bool shouldAsk({
    required DateTime now,
    required int savesSinceAsk,
    required int timesAsked,
    required DateTime firstSave,
    DateTime? lastAsked,
  }) {
    if (timesAsked >= maxAsks) return false;
    if (lastAsked == null) {
      return savesSinceAsk >= firstAskAfterSaves && now.difference(firstSave) >= const Duration(days: 1);
    }
    return savesSinceAsk >= laterAskAfterSaves && now.difference(lastAsked) >= askInterval;
  }

  static DateTime? _readTime(SharedPreferences prefs, String key) {
    final ms = prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
