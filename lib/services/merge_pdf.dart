import 'package:flutter/services.dart';

/// Invokes the native code to merge multiple PDF files.
///
/// Returns the [String] path to the temporary merged PDF file created in the app's cache.
Future<String> mergePdfsNative(List<String> filePaths) async {
  const platform = MethodChannel('bluepdf.native/Pdf_utility');

  try {
    // Invoke the 'mergePdfs' method on the native side.
    final String? filePath = await platform.invokeMethod<String>(
      'mergePdfs',
      {'paths': filePaths},
    );

    if (filePath == null || filePath.isEmpty) {
      throw Exception('Native code failed to merge PDFs and return a file path.');
    }

    return filePath;

  } on PlatformException catch (e) {
    print("PlatformException in mergePdfsNative: ${e.message}");
    rethrow;
  }
}