import 'package:flutter/services.dart';

const _channel = MethodChannel('com.bluepdf.channel/pdf');

Future<List<String>> reorderPdfNative(String inputPath, int compressionValue) async {
  try {
    final List<String>? filePath = await _channel.invokeMethod<List<String>>(
      'reorderPdf',
      {
        'path': inputPath,
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