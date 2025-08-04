import 'package:flutter/services.dart';

const _channel = MethodChannel('com.bluepdf.channel/pdf');

Future<String> imageToPdfNative(List<String> imagePaths, String pageMode) async {
  try {
    final String? filePath = await _channel.invokeMethod<String>(
      'imageToPdf',
      {
        'paths': imagePaths,
        'pageMode': pageMode // either "A4" or "FIT"
      },
    );
    if (filePath == null || filePath.isEmpty) {
      throw Exception('Failed to generate PDF from images.');
    }
    return filePath;
  } on PlatformException catch (e) {
    print("imageToPdfNative failed: ${e.message}");
    rethrow;
  }
}