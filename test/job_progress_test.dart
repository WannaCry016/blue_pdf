import 'dart:async';

import 'package:blue_pdf/components/job_progress.dart';
import 'package:blue_pdf/pdf/pdf_engine.dart';
import 'package:blue_pdf/pdf/pdf_job.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Starts runWithProgress from a real BuildContext and records the outcome.
class _Run<T> {
  T? value;
  Object? error;
  bool get settled => value != null || error != null;
}

Future<_Run<T>> _start<T>(
  WidgetTester tester, {
  required Future<T> Function(PdfJob job) task,
  ProgressDescriber describe = describeProgress,
}) async {
  final run = _Run<T>();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => runWithProgress(context, title: 'Merging 2 PDFs', describe: describe, task: task).then(
              (v) {
                run.value = v;
              },
              onError: (Object e) {
                run.error = e;
              },
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  return run;
}

// The bar is indeterminate until the first event, so pumpAndSettle would never settle.
const _transition = Duration(milliseconds: 300);

void main() {
  testWidgets('a job that finishes quickly never shows a dialog', (tester) async {
    final run = await _start(tester, task: (_) => Future.delayed(const Duration(milliseconds: 300), () => 'ok'));

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(JobProgressDialog), findsNothing);
    expect(run.value, 'ok');
  });

  testWidgets('a slow job shows real progress and closes after reaching 100%', (tester) async {
    final work = Completer<String>();
    late PdfJob job;
    final run = await _start(
      tester,
      task: (j) {
        job = j;
        return work.future;
      },
    );

    await tester.pump(const Duration(milliseconds: 399));
    expect(find.byType(JobProgressDialog), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(_transition);
    expect(find.text('Merging 2 PDFs'), findsOneWidget);
    expect(find.text('Starting...'), findsOneWidget);

    job.report(const PdfProgress(stage: PdfStage.processing, done: 3, total: 10, fraction: 0.15));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    expect(find.text('3 of 10'), findsOneWidget);
    expect(find.text('15%'), findsOneWidget);

    work.complete('/out.pdf');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 230));
    // Up for less than the minimum so far: still showing, now full.
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(run.settled, isFalse);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.byType(JobProgressDialog), findsNothing);
    expect(run.value, '/out.pdf');
  });

  testWidgets('Cancel cancels the job and closes without waiting', (tester) async {
    final run = await _start<String>(
      tester,
      task: (job) {
        final work = Completer<String>();
        job.onCancel(() => work.completeError(const PdfFailure(PdfErrorCode.cancelled)));
        return work.future;
      },
    );

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(_transition);
    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(run.error, isA<PdfFailure>().having((f) => f.code, 'code', PdfErrorCode.cancelled));
    await tester.pumpAndSettle();
    expect(find.byType(JobProgressDialog), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('back does not dismiss the progress dialog', (tester) async {
    final work = Completer<String>();
    final run = await _start(tester, task: (_) => work.future);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(_transition);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pump(_transition);
    expect(find.byType(JobProgressDialog), findsOneWidget);

    work.complete('done');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(run.value, 'done');
  });

  test('describeProgress', () {
    expect(describeProgress(PdfProgress.items(4, 9)), '4 of 9');
    expect(describeProgress(const PdfProgress(stage: PdfStage.writing, fraction: 0.6)), 'Saving...');
    expect(describeProgress(PdfProgress.complete), 'Done');
  });

  group('PdfJob', () {
    test('cancel runs handlers once, and late handlers immediately', () {
      final job = PdfJob();
      var calls = 0;
      job.onCancel(() => calls++);
      job
        ..cancel()
        ..cancel();
      expect(calls, 1);
      job.onCancel(() => calls++);
      expect(calls, 2);
      expect(job.throwIfCancelled, throwsA(isA<PdfFailure>()));
    });

    test('jobs get distinct ids', () {
      expect(PdfJob().id, isNot(PdfJob().id));
    });
  });
}
