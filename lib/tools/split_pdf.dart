import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
const _channel = MethodChannel('com.bluepdf.channel/pdf');

Future<String> splitPdfNative(String inputPath, List<int> pagesToSplit) async {
  try {
    final String? outputPaths = await _channel.invokeMethod<String>(
      'splitPdf',
      {
        'path': inputPath,
        'pages': pagesToSplit,
      },
    );
    if (outputPaths == null || outputPaths.isEmpty) {
      throw Exception('Failed to split PDF.');
    }
    return outputPaths;
  } on PlatformException catch (e) {
    debugPrint("splitPdfNative failed: ${e.message}");
    rethrow;
  }
}