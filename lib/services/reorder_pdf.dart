import 'package:flutter/services.dart';

class ReorderPdfService {
  static const MethodChannel _channel = MethodChannel('bluepdf.native/Pdf_utility');

  /// Converts each page of the PDF at [path] to an image and returns the list of image paths.
  static Future<List<String>> reorderPdf(String path) async {
    final result = await _channel.invokeMethod<List<dynamic>>('reorderPdf', {
      'path': path,
    });
    if (result == null) {
      throw Exception('Failed to convert PDF to images');
    }
    return result.cast<String>();
  }
} 