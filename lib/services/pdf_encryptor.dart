import 'package:flutter/services.dart';

const _channel = MethodChannel('com.bluepdf.channel/pdf');

Future<String> encryptPdfNative(String inputPath, String password, int compressionValue) async {
  try {
    final String? filePath = await _channel.invokeMethod<String>(
      'encryptPdf',
      {
        'path': inputPath,
        'password': password,
      },
    );
    if (filePath == null || filePath.isEmpty) {
      throw Exception('Failed to encrypt PDF.');
    }
    return filePath;
  } on PlatformException catch (e) {
    print("encryptPdfNative failed: ${e.message}");
    
    // Handle specific error cases with proper error messages
    switch (e.code) {
      case 'ALREADY_ENCRYPTED':
        throw Exception('PDF is already encrypted');
      case 'ENCRYPTION_FAILED':
        throw Exception('Failed to encrypt PDF: ${e.message ?? 'Unknown encryption error'}');
      case 'CONTEXT_FAILED':
        throw Exception('PDF processing initialization failed');
      case 'INVALID_ARGUMENT':
        throw Exception('Invalid input parameters provided');
      default:
        throw Exception('Encryption error: ${e.message ?? 'Unknown error occurred'}');
    }
  }
}