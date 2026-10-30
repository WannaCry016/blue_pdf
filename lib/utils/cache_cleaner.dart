import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Deletes cached files (picked copies, results, thumbnails, camera shots)
/// last modified before [before], then any folders left empty.
///
/// Files written after [before] are kept, so cleaning at startup can't race
/// with files the user picks while it runs. All file work is async, so it
/// never blocks a frame.
Future<void> clearCache({required DateTime before, Directory? directory}) async {
  try {
    final root = directory ?? await getTemporaryDirectory();
    var deleted = 0;
    Future<void> sweep(Directory dir) async {
      await for (final entity in dir.list(followLinks: false)) {
        try {
          // Read before sweeping: deleting children updates a folder's time.
          final stale = (await entity.stat()).modified.isBefore(before);
          if (entity is Directory) {
            await sweep(entity);
            // Fails, and is skipped, when something new is still inside.
            if (stale) await entity.delete();
          } else if (stale) {
            await entity.delete();
            deleted++;
          }
        } on FileSystemException {
          // In use or already gone.
        }
      }
    }

    if (await root.exists()) await sweep(root);
    if (deleted > 0) debugPrint('Cache: removed $deleted stale files');
  } catch (e) {
    debugPrint('Cache cleanup failed: $e');
  }
}
