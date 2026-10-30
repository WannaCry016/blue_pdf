import 'dart:async';

import 'package:flutter/material.dart';

import '../pdf/pdf_job.dart';

/// Puts a job's progress into words, e.g. "120 of 330 pages".
typedef ProgressDescriber = String Function(PdfProgress progress);

String describeProgress(PdfProgress progress) => switch (progress.stage) {
      PdfStage.processing => progress.total > 0 ? '${progress.done} of ${progress.total}' : 'Preparing...',
      PdfStage.writing => progress.fraction >= 1 ? 'Done' : 'Saving...',
    };

/// Runs [task] and shows its progress only when it is slow enough to need it.
///
/// Jobs that finish within [showAfter] never show anything. Slower jobs get a
/// progress dialog that stays up for at least [minVisible] and fills to 100%
/// before closing, so it never flashes. The same rules as Android's
/// ContentLoadingProgressBar, applied to a dialog.
///
/// Cancelling calls [PdfJob.cancel]; [task] is expected to then fail with
/// [PdfErrorCode.cancelled], which is rethrown like any other error.
Future<T> runWithProgress<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(PdfJob job) task,
  ProgressDescriber describe = describeProgress,
  bool cancellable = true,
  Duration showAfter = const Duration(milliseconds: 400),
  Duration minVisible = const Duration(milliseconds: 600),
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final job = PdfJob();
  Route<void>? dialog;
  final shownLongEnough = Completer<void>();

  final reveal = Timer(showAfter, () {
    if (!navigator.mounted) return;
    Timer(minVisible, shownLongEnough.complete);
    dialog = DialogRoute<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => JobProgressDialog(
        job: job,
        title: title,
        describe: describe,
        cancellable: cancellable,
      ),
    );
    navigator.push(dialog!);
  });

  var succeeded = false;
  try {
    final result = await task(job);
    succeeded = true;
    return result;
  } finally {
    reveal.cancel();
    final shown = dialog;
    if (shown != null) {
      if (succeeded) {
        job.report(PdfProgress.complete);
        await Future.wait([shownLongEnough.future, Future<void>.delayed(_completionPause)]);
      }
      if (shown.isCurrent) {
        navigator.pop();
      } else if (shown.isActive) {
        navigator.removeRoute(shown);
      }
    }
  }
}

/// Long enough to see the bar animate to the end (see [_barAnimation]) and rest there.
const _completionPause = Duration(milliseconds: 300);
const _barAnimation = Duration(milliseconds: 220);

class JobProgressDialog extends StatefulWidget {
  const JobProgressDialog({
    super.key,
    required this.job,
    required this.title,
    this.describe = describeProgress,
    this.cancellable = true,
  });

  final PdfJob job;
  final String title;
  final ProgressDescriber describe;
  final bool cancellable;

  @override
  State<JobProgressDialog> createState() => _JobProgressDialogState();
}

class _JobProgressDialogState extends State<JobProgressDialog> {
  void _cancel() => setState(widget.job.cancel);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF536DFE) : Colors.blueAccent;
    final secondary = isDark ? Colors.white70 : Colors.black54;
    final cancelling = widget.job.isCancelled;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 22, 24, widget.cancellable ? 8 : 22),
          child: ValueListenableBuilder<PdfProgress?>(
            valueListenable: widget.job.progress,
            builder: (context, progress, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 18),
                // Native progress arrives in steps; animating between them keeps the bar smooth.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress?.fraction ?? 0),
                  duration: _barAnimation,
                  curve: Curves.easeOut,
                  builder: (context, value, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        value: progress == null ? null : value,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                        color: accent,
                        backgroundColor: accent.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              cancelling
                                  ? 'Cancelling...'
                                  : progress == null
                                      ? 'Starting...'
                                      : widget.describe(progress),
                              style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (progress != null)
                            Text(
                              '${(value * 100).floor()}%',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: secondary,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.cancellable)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: cancelling ? null : _cancel,
                      child: const Text('Cancel'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
