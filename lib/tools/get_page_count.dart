import 'package:flutter/services.dart';

const _channel = MethodChannel('com.bluepdf.channel/pdf');

Future<int> getPdfPageCount(String path) async {
  final count = await _channel.invokeMethod<int>('getPdfPageCount', {'pdfPath': path});
  return count ?? 1;
}
