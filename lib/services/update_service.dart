import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Keeps the app current through Google Play in-app updates.
///
/// Every launch with an update available shows Play's own sheet. An accepted
/// update downloads in the background while the user keeps working, then
/// [check] calls `onReady` so the app can offer a restart; nothing restarts the
/// app until the user asks for it with [installDownloaded].
class UpdateService {
  UpdateService({
    Future<AppUpdateInfo> Function()? checkForUpdate,
    Future<AppUpdateResult> Function()? startFlexibleUpdate,
    Future<AppUpdateResult> Function()? performImmediateUpdate,
    Future<void> Function()? completeFlexibleUpdate,
  })  : _checkForUpdate = checkForUpdate ?? InAppUpdate.checkForUpdate,
        _startFlexibleUpdate = startFlexibleUpdate ?? InAppUpdate.startFlexibleUpdate,
        _performImmediateUpdate = performImmediateUpdate ?? InAppUpdate.performImmediateUpdate,
        _completeFlexibleUpdate = completeFlexibleUpdate ?? InAppUpdate.completeFlexibleUpdate;

  static final instance = UpdateService();

  final Future<AppUpdateInfo> Function() _checkForUpdate;
  final Future<AppUpdateResult> Function() _startFlexibleUpdate;
  final Future<AppUpdateResult> Function() _performImmediateUpdate;
  final Future<void> Function() _completeFlexibleUpdate;

  bool _checking = false;

  /// Offers an available update and calls [onReady] once one is downloaded,
  /// including one downloaded in an earlier session but never installed.
  Future<void> check({required VoidCallback onReady}) async {
    if (_checking) return;
    _checking = true;
    try {
      final info = await _checkForUpdate();
      if (info.installStatus == InstallStatus.downloaded) {
        onReady();
        return;
      }
      // An immediate update the user started is resumed, as Play requires.
      if (info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
        await _performImmediateUpdate();
        return;
      }
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

      // Flexible completes once the download finishes, or when declined.
      if (info.flexibleUpdateAllowed) {
        if (await _startFlexibleUpdate() == AppUpdateResult.success) onReady();
      } else if (info.immediateUpdateAllowed) {
        await _performImmediateUpdate();
      }
    } catch (e) {
      // Updating must never get in the way of using the app.
      debugPrint('Update check skipped: $e');
    } finally {
      _checking = false;
    }
  }

  /// Restarts the app into the update that [check] reported as ready.
  Future<void> installDownloaded() async {
    try {
      await _completeFlexibleUpdate();
    } catch (e) {
      debugPrint('Could not install the update: $e');
    }
  }

  /// The user-facing version, e.g. "1.0.3" (without the Play build number).
  static Future<String> getCurrentVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
}
