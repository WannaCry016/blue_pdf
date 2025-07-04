import 'package:flutter/services.dart';

/// Invokes the native code to generate a PDF from images.
///
/// Returns the [String] path to the temporary PDF file created in the app's cache.
Future<String> imageToPdfNative(List<String> imagePaths) async {
  const platform = MethodChannel('bluepdf.native/Pdf_utility');

  try {
    // We expect a String path from the native side.
    final String? filePath = await platform.invokeMethod<String>(
      'generatePdfFromImages',
      {'paths': imagePaths},
    );

    // If the native code fails to produce a path, throw an exception.
    if (filePath == null || filePath.isEmpty) {
      throw Exception('Native code failed to generate PDF and return a file path.');
    }

    // Return the path directly. No reading or deleting here.
    return filePath;
    
  } on PlatformException catch (e) {
    // Forward any platform exceptions for the caller to handle.
    print("PlatformException in imageToPdfNative: ${e.message}");
    rethrow;
  }
}