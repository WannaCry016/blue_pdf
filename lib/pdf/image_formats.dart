import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../state_providers.dart';

/// Image formats MuPDF can embed directly.
const nativeImageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'tif', 'tiff'};

/// Returns [file] if MuPDF can read it, otherwise a JPEG copy (HEIC, WebP, ...).
/// Returns null when the image cannot be decoded on this device.
Future<SelectedFile?> ensureNativeImage(SelectedFile file) async {
  if (nativeImageExtensions.contains(file.extension)) return file;

  final baseName = p.basenameWithoutExtension(file.name);
  try {
    final dir = await getTemporaryDirectory();
    final target = p.join(dir.path, '${baseName}_${DateTime.now().microsecondsSinceEpoch}.jpg');
    final converted = await FlutterImageCompress.compressAndGetFile(
      file.path,
      target,
      format: CompressFormat.jpeg,
      quality: 92,
      // Large minimums keep the original resolution.
      minWidth: 100000,
      minHeight: 100000,
      autoCorrectionAngle: true,
    );
    if (converted == null || !await File(converted.path).exists()) return null;
    return SelectedFile(name: '$baseName.jpg', path: converted.path, rotation: file.rotation);
  } catch (e) {
    debugPrint('Image conversion failed for ${file.name}: $e');
    return null;
  }
}
