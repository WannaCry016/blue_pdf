import 'package:flutter/services.dart';

const _channel = MethodChannel('com.bluepdf.channel/pdf');

Future<List<String>> reorderPdfNative(String inputPath) async {
  try {
    final dynamic result = await _channel.invokeMethod(
      'reorderPdf',
      {
        'path': inputPath,
      },
    );
    
    if (result == null) {
      throw Exception('Failed to reorder PDF: null result');
    }
    
    // Convert the result to List<String>
    if (result is List) {
      final List<String> filePaths = result.cast<String>();
      if (filePaths.isEmpty) {
        throw Exception('Failed to reorder PDF: empty result');
      }
      return filePaths;
    } else {
      throw Exception('Failed to reorder PDF: unexpected result type');
    }
  } on PlatformException catch (e) {
    print("reorderPdfNative failed: ${e.message}");
    rethrow;
  }
}