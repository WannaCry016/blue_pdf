import 'package:flutter/services.dart';

class SplitPdfService {
  static const MethodChannel _channel = MethodChannel('bluepdf.native/Pdf_utility');

  /// Splits the PDF at [path] from [startPage] to [endPage] (inclusive) and returns the output file path.
  static Future<String> splitPdf(String path, int startPage, int endPage) async {
    final result = await _channel.invokeMethod<String>('splitPdf', {
      'path': path,
      'startPage': startPage,
      'endPage': endPage,
    });
    if (result == null || result.isEmpty) {
      throw Exception('Failed to split PDF');
    }
    return result;
  }
} 