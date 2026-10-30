import 'package:flutter/foundation.dart';

import 'pdf_engine.dart';

/// Values match `bluepdf::Stage` in android/app/src/main/cpp/pdf_ops.h.
enum PdfStage {
  /// Working through items: [PdfProgress.done] of [PdfProgress.total].
  processing,

  /// Writing the output file.
  writing,
}

@immutable
class PdfProgress {
  const PdfProgress({
    required this.stage,
    required this.fraction,
    this.done = 0,
    this.total = 0,
  });

  /// Progress of work done in Dart, counted in items.
  factory PdfProgress.items(int done, int total) => PdfProgress(
        stage: PdfStage.processing,
        done: done,
        total: total,
        fraction: total == 0 ? 0 : done / total,
      );

  static const complete = PdfProgress(stage: PdfStage.writing, fraction: 1);

  final PdfStage stage;
  final int done;
  final int total;

  /// Of the whole job, from 0 to 1. Never decreases within a job.
  final double fraction;

  @override
  bool operator ==(Object other) =>
      other is PdfProgress &&
      other.stage == stage &&
      other.done == done &&
      other.total == total &&
      other.fraction == fraction;

  @override
  int get hashCode => Object.hash(stage, done, total, fraction);

  @override
  String toString() => 'PdfProgress(${stage.name} $done/$total ${(fraction * 100).toStringAsFixed(1)}%)';
}

/// One long-running piece of work: carries its progress to the UI and its
/// cancellation to whoever does the work (native code or a Dart loop).
class PdfJob {
  PdfJob();

  static int _nextId = 1;

  final int id = _nextId++;

  /// Null until the first report.
  final ValueNotifier<PdfProgress?> progress = ValueNotifier(null);

  final List<VoidCallback> _cancelHandlers = [];
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void report(PdfProgress value) => progress.value = value;

  /// Runs [handler] when the job is cancelled, or right away if it already is.
  void onCancel(VoidCallback handler) {
    if (_cancelled) {
      handler();
    } else {
      _cancelHandlers.add(handler);
    }
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final handler in _cancelHandlers) {
      handler();
    }
    _cancelHandlers.clear();
  }

  void throwIfCancelled() {
    if (_cancelled) throw const PdfFailure(PdfErrorCode.cancelled);
  }
}
