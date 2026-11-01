import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the app current through Google Play in-app updates.
///
/// Play's own sheet asks the user. An accepted update downloads in the
/// background while they keep working, then [check] calls `onReady` so the
/// app can offer a restart; nothing restarts the app until the user asks for
/// it with [installDownloaded]. A declined version is not offered again for
/// [askInterval], so it never nags on every launch; a newer version is
/// offered straight away.
class UpdateService {
  UpdateService({
    Future<AppUpdateInfo> Function()? checkForUpdate,
    Future<AppUpdateResult> Function()? startFlexibleUpdate,
    Future<AppUpdateResult> Function()? performImmediateUpdate,
    Future<void> Function()? completeFlexibleUpdate,
    DateTime Function()? now,
  })  : _checkForUpdate = checkForUpdate ?? InAppUpdate.checkForUpdate,
        _startFlexibleUpdate = startFlexibleUpdate ?? InAppUpdate.startFlexibleUpdate,
        _performImmediateUpdate = performImmediateUpdate ?? InAppUpdate.performImmediateUpdate,
        _completeFlexibleUpdate = completeFlexibleUpdate ?? InAppUpdate.completeFlexibleUpdate,
        _now = now ?? DateTime.now;

  static final instance = UpdateService();

  static const askInterval = Duration(days: 3);
  static const _declinedVersionKey = 'update_declined_version';
  static const _declinedAtKey = 'update_declined_at';

  final Future<AppUpdateInfo> Function() _checkForUpdate;
  final Future<AppUpdateResult> Function() _startFlexibleUpdate;
  final Future<AppUpdateResult> Function() _performImmediateUpdate;
  final Future<void> Function() _completeFlexibleUpdate;
  final DateTime Function() _now;

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
      if (!info.flexibleUpdateAllowed && !info.immediateUpdateAllowed) return;
      final version = info.availableVersionCode ?? 0;
      if (await _recentlyDeclined(version)) return;

      // Flexible completes once the download finishes, or as declined.
      final result = info.flexibleUpdateAllowed ? await _startFlexibleUpdate() : await _performImmediateUpdate();
      if (result == AppUpdateResult.userDeniedUpdate) {
        await _rememberDeclined(version);
      } else if (result == AppUpdateResult.success && info.flexibleUpdateAllowed) {
        onReady();
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

  Future<bool> _recentlyDeclined(int version) async {
    final prefs = await SharedPreferences.getInstance();
    final declinedVersion = prefs.getInt(_declinedVersionKey);
    final declinedAt = prefs.getInt(_declinedAtKey);
    if (declinedVersion == null || declinedAt == null || version > declinedVersion) return false;
    return _now().difference(DateTime.fromMillisecondsSinceEpoch(declinedAt)) < askInterval;
  }

  Future<void> _rememberDeclined(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_declinedVersionKey, version);
    await prefs.setInt(_declinedAtKey, _now().millisecondsSinceEpoch);
  }

  /// The user-facing version, e.g. "1.0.3" (without the Play build number).
  static Future<String> getCurrentVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
}
