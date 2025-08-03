import 'package:flutter/services.dart';

const _channel = MethodChannel('com.bluepdf.channel/pdf');

Future<String> renderSinglePage(String path, int pageIndex) async {
  try {
    final String? imagePath = await _channel.invokeMethod<String>(
      'renderPdfPage',
      {
        'pdfPath': path,
        'pageIndex': pageIndex - 1,
      },
    );
    if (imagePath == null || imagePath.isEmpty) {
      throw Exception('Failed to render page.');
    }
    return imagePath;
  } on PlatformException catch (e) {
    print("renderSinglePage failed: ${e.message}");
    rethrow;
  }
}
