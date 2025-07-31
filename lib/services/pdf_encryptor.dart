import 'package:flutter/services.dart';
const _channel = MethodChannel('com.bluepdf.channel/pdf');

Future<String> encryptPdfNative(String inputPath, String password, int compressionValue) async {
  try {
    final String? filePath = await _channel.invokeMethod<String>(
      'encryptPdf',
      {
        'path': inputPath,
        'password': password,
        'compression': compressionValue,
      },
    );
    if (filePath == null || filePath.isEmpty) {
      throw Exception('Failed to encrypt PDF.');
    }
    return filePath;
  } on PlatformException catch (e) {
    print("encryptPdfNative failed:  ${e.message}");
    rethrow;
  }
}