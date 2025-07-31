import 'package:flutter/services.dart';
const _channel = MethodChannel('com.bluepdf.channel/pdf');

Future<String> mergePdfNative(List<String> pdfPaths, int compressionValue) async {
  try {
    final String? filePath = await _channel.invokeMethod<String>(
      'mergePdf',
      {
        'paths': pdfPaths,
        'compression': compressionValue,
      },
    );
    if (filePath == null || filePath.isEmpty) {
      throw Exception('Failed to merge PDFs.');
    }
    return filePath;
  } on PlatformException catch (e) {
    print("mergePdfNative failed:  ${e.message}");
    rethrow;
  }
}