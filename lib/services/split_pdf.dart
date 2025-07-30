import 'package:flutter/services.dart';

/// Splits the PDF at [path] from [startPage] to [endPage] (inclusive) and returns the output file path.
Future<String> splitPdf(String path, int startPage, int endPage, int compressionValue) async {
  const MethodChannel _channel = MethodChannel('bluepdf.native/Pdf_utility');
  try {
    final result = await _channel.invokeMethod<String>('splitPdf', {
      'path': path,
      'startPage': startPage,
      'endPage': endPage,
      'compression': compressionValue, // 1=Low, 2=Medium, 3=High
    });
    if (result == null || result.isEmpty) {
      throw Exception('Failed to split PDF');
    }
    return result;
  } on PlatformException catch (e) {
    print("PlatformException in splitPdf: ${e.message}");
    rethrow;
  }
} 