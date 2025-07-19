import 'package:flutter/services.dart';

class ReorderPdfService {
  static const MethodChannel _channel = MethodChannel('bluepdf.native/Pdf_utility');

  /// Converts each page of the PDF at [path] to an image and returns the list of image paths.
  static Future<List<String>> reorderPdf(String path) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('reorderPdf', {
        'path': path,
      });
      
      if (result == null) {
        throw Exception('Native method returned null result');
      }
      
      if (result.isEmpty) {
        throw Exception('PDF conversion resulted in no images');
      }
      
      return result.cast<String>();
    } on PlatformException catch (e) {
      throw Exception('Platform error: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('Failed to convert PDF to images: $e');
    }
  }
} 