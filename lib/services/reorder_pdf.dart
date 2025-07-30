import 'package:flutter/services.dart';

/// Converts each page of the PDF at [path] to an image and returns the list of image paths.
Future<List<String>> reorderPdf(String path, int compressionValue) async {
  const MethodChannel _channel = MethodChannel('bluepdf.native/Pdf_utility');
  try {
    final result = await _channel.invokeMethod<List<dynamic>>('reorderPdf', {
      'path': path,
      'compression': compressionValue, // 1=Low, 2=Medium, 3=High
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
 