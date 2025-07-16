import 'package:flutter/services.dart';

Future<String?> unlockPdf(String path, String password) async {
  const platform = MethodChannel('bluepdf.native/Pdf_utility');
  try {
    final result = await platform.invokeMethod<String>('unlockPdf', {
      'path': path,
      'password': password,
    });
    return result;
  } catch (e) {
    print('❌ Error unlocking PDF: $e');
    return null;
  }
}
