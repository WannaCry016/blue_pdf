import 'package:flutter/services.dart';
const _channel = MethodChannel('com.bluepdf.channel/pdf');

Future<List<String>> splitPdfNative(String inputPath, List<int> pagesToSplit) async {
  try {
    final List<dynamic>? outputPaths = await _channel.invokeMethod<List<dynamic>>(
      'splitPdf',
      {
        'path': inputPath,
        'pages': pagesToSplit,
      },
    );
    if (outputPaths == null || outputPaths.isEmpty) {
      throw Exception('Failed to split PDF.');
    }
    return outputPaths.cast<String>();
  } on PlatformException catch (e) {
    print("splitPdfNative failed: ${e.message}");
    rethrow;
  }
}