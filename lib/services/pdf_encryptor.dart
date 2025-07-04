import 'package:flutter/services.dart';

Future<String?> encryptPdf(String path, String password) async {
  const platform = MethodChannel('bluepdf.native/Pdf_utility');
  try {
    final result = await platform.invokeMethod<String>('encryptPdf', {
      'path': path,
      'password': password,
    });
    return result;
  } catch (e) {
    print('❌ Error encrypting PDF: $e');
    return null;
  }
}
