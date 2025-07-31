import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static bool _isCheckingForUpdate = false;

  /// Check for available updates
  static Future<void> checkForUpdate(BuildContext context) async {
    if (_isCheckingForUpdate) return;
    _isCheckingForUpdate = true;

    try {
      // Check if update is available
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        // Show update dialog
        _showUpdateDialog(context, updateInfo);
      }
    } catch (e) {
      print('Error checking for update: $e');
    } finally {
      _isCheckingForUpdate = false;
    }
  }

  /// Show update dialog to user
  static void _showUpdateDialog(BuildContext context, AppUpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A new version of the app is available.'),
              const SizedBox(height: 16),
              const Text('Would you like to update now?'),
              if (updateInfo.immediateUpdateAllowed)
                const SizedBox(height: 8),
              if (updateInfo.immediateUpdateAllowed)
                const Text(
                  'This update contains important improvements.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
            ],
          ),
          actions: [
            if (updateInfo.flexibleUpdateAllowed)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _performFlexibleUpdate();
                },
                child: const Text('Update in Background'),
              ),
            if (updateInfo.immediateUpdateAllowed)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _performImmediateUpdate();
                },
                child: const Text('Update Now'),
              )
          ],
        );
      },
    );
  }

  /// Perform immediate update (app restarts after update)
  static Future<void> _performImmediateUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      print('Error performing immediate update: $e');
    }
  }

  /// Perform flexible update (download in background)
  static Future<void> _performFlexibleUpdate() async {
    try {
      await InAppUpdate.startFlexibleUpdate();
      
      // Listen for download completion
      InAppUpdate.completeFlexibleUpdate().then((_) {
        // Show snackbar or restart app
        print('Flexible update completed');
      });
    } catch (e) {
      print('Error performing flexible update: $e');
    }
  }

  /// Force check for critical updates (call on app start)
  static Future<void> checkForCriticalUpdate(BuildContext context) async {
    try {
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          // For critical updates, show non-dismissible dialog
          _showCriticalUpdateDialog(context);
        } else {
          _showUpdateDialog(context, updateInfo);
        }
      }
    } catch (e) {
      print('Error checking for critical update: $e');
    }
  }

  /// Show critical update dialog (non-dismissible)
  static void _showCriticalUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: AlertDialog(
            title: const Text('Critical Update Required'),
            content: const Text(
              'This update contains important security fixes and is required to continue using the app.',
            ),
            actions: [
              ElevatedButton(
                onPressed: _performImmediateUpdate,
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Get current app version
  static Future<String> getCurrentVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version} (${packageInfo.buildNumber})';
  }
}