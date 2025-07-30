import 'package:flutter/services.dart';

Future<String?> encryptPdf(String path, String password, int compressionValue) async {
  const platform = MethodChannel('bluepdf.native/Pdf_utility');
  try {
    final result = await platform.invokeMethod<String>('encryptPdf', {
      'path': path,
      'password': password,
      'compression': compressionValue, // 1=Low, 2=Medium, 3=High
    });
    return result;
  } catch (e) {
    print('❌ Error encrypting PDF: $e');
    return null;
  }
}
