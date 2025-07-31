import 'package:flutter/services.dart';

const _channel = MethodChannel('com.bluepdf.channel/pdf');

Future<String> reorderPdfNative(String inputPath, int compressionValue) async {
  try {
    final String? filePath = await _channel.invokeMethod<String>(
      'reorderPdf',
      {
        'path': inputPath,
        'compression': compressionValue,
      },
    );
    if (filePath == null || filePath.isEmpty) {
      throw Exception('Failed to reorder PDF.');
    }
    return filePath;
  } on PlatformException catch (e) {
    print("reorderPdfNative failed: ${e.message}");
    rethrow;
  }
}