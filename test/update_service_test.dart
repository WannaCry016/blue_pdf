import 'package:blue_pdf/components/update_ready_snack_bar.dart';
import 'package:blue_pdf/services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppUpdateInfo info({
  UpdateAvailability availability = UpdateAvailability.updateAvailable,
  InstallStatus status = InstallStatus.unknown,
  bool flexible = true,
  bool immediate = true,
  int version = 23,
}) =>
    AppUpdateInfo(
      updateAvailability: availability,
      immediateUpdateAllowed: immediate,
      immediateAllowedPreconditions: null,
      flexibleUpdateAllowed: flexible,
      flexibleAllowedPreconditions: null,
      availableVersionCode: version,
      installStatus: status,
      packageName: 'com.bluepdf.blue_pdf',
      clientVersionStalenessDays: 0,
      updatePriority: 0,
    );

void main() {
  late List<String> calls;
  late AppUpdateInfo current;
  late AppUpdateResult flexibleResult;
  late DateTime now;
  late int readyCount;

  UpdateService service() => UpdateService(
        checkForUpdate: () async => current,
        startFlexibleUpdate: () async {
          calls.add('flexible');
          return flexibleResult;
        },
        performImmediateUpdate: () async {
          calls.add('immediate');
          return AppUpdateResult.success;
        },
        completeFlexibleUpdate: () async => calls.add('install'),
        now: () => now,
      );

  Future<void> check() => service().check(onReady: () => readyCount++);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    current = info();
    flexibleResult = AppUpdateResult.success;
    now = DateTime(2026, 11, 1, 10);
    readyCount = 0;
  });

  test('downloads in the background and reports ready without restarting', () async {
    await check();

    expect(calls, ['flexible']);
    expect(readyCount, 1);
  });

  test('a declined update is not ready and not offered again for a few days', () async {
    flexibleResult = AppUpdateResult.userDeniedUpdate;
    await check();
    expect(readyCount, 0);

    now = now.add(const Duration(days: 2));
    await check();
    expect(calls, ['flexible']);

    now = now.add(const Duration(days: 1));
    await check();
    expect(calls, ['flexible', 'flexible']);
  });

  test('a newer version is offered straight away, even after declining one', () async {
    flexibleResult = AppUpdateResult.userDeniedUpdate;
    await check();

    current = info(version: 24);
    now = now.add(const Duration(hours: 1));
    await check();

    expect(calls, ['flexible', 'flexible']);
  });

  test('accepting an update does not hold back the next one', () async {
    await check();

    current = info(version: 24);
    now = now.add(const Duration(hours: 1));
    await check();

    expect(calls, ['flexible', 'flexible']);
    expect(readyCount, 2);
  });

  test('an update that failed to start is offered again on the next launch', () async {
    flexibleResult = AppUpdateResult.inAppUpdateFailed;
    await check();
    await check();

    expect(calls, ['flexible', 'flexible']);
    expect(readyCount, 0);
  });

  test('an update downloaded earlier is offered for restart straight away', () async {
    current = info(status: InstallStatus.downloaded);

    await check();

    expect(calls, isEmpty);
    expect(readyCount, 1);
  });

  test('an interrupted immediate update is resumed', () async {
    current = info(availability: UpdateAvailability.developerTriggeredUpdateInProgress);

    await check();

    expect(calls, ['immediate']);
  });

  test('falls back to an immediate update when background download is not allowed', () async {
    current = info(flexible: false);

    await check();

    expect(calls, ['immediate']);
    expect(readyCount, 0);
  });

  test('does nothing without an update, or when Play cannot be reached', () async {
    current = info(availability: UpdateAvailability.updateNotAvailable);
    await check();

    await UpdateService(checkForUpdate: () => throw Exception('no Play')).check(onReady: () => readyCount++);

    expect(calls, isEmpty);
    expect(readyCount, 0);
  });

  test('installDownloaded restarts into the update', () async {
    await service().installDownloaded();
    expect(calls, ['install']);
  });

  testWidgets('the ready message stays until the user restarts', (tester) async {
    var restarted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              updateReadySnackBar(onRestart: () => restarted = true),
            ),
            child: const Text('show'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Update ready. Restart to install.'), findsOneWidget);

    await tester.tap(find.text('Restart'));
    expect(restarted, isTrue);
  });
}
