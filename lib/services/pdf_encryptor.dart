import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Encrypts a PDF using only a user password.
/// This makes the PDF require a password to open.
Future<List<int>> encryptPdf({
  required Uint8List pdfBytes,
  required String userPassword,
}) async {
  // Load the existing PDF document
  final PdfDocument document = PdfDocument(inputBytes: pdfBytes);

  // Set only the user password
  document.security.userPassword = userPassword;

  // Save and return encrypted PDF as bytes
  final List<int> encryptedBytes = await document.save();

  // Dispose the document to free resources
  document.dispose();

  return encryptedBytes;
}
