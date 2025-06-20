import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';

Future<Uint8List> mergePDFs(List<String> filePaths) async {
  final outputPdf = PdfDocument();

  for (final path in filePaths) {
    final bytes = File(path).readAsBytesSync();
    final doc = PdfDocument(inputBytes: bytes);

    for (int i = 0; i < doc.pages.count; i++) {
      final template = doc.pages[i].createTemplate();
      final originalWidth = template.size.width;
      final originalHeight = template.size.height;

      final newPage = outputPdf.pages.add();
      final targetSize = newPage.getClientSize();
      final targetWidth = targetSize.width;
      final targetHeight = targetSize.height;

      // Calculate scale factor (maintain aspect ratio)
      final scaleX = targetWidth / originalWidth;
      final scaleY = targetHeight / originalHeight;
      final scale = scaleX < scaleY ? scaleX : scaleY;

      final drawWidth = originalWidth * scale;
      final drawHeight = originalHeight * scale;

      final offsetX = (targetWidth - drawWidth) / 2;
      final offsetY = (targetHeight - drawHeight) / 2;

      // Draw template with correct position and scaled size
      newPage.graphics.drawPdfTemplate(
        template,
        Offset(offsetX, offsetY),
        Size(drawWidth, drawHeight),
      );
    }

    doc.dispose();
  }

  final resultBytes = await outputPdf.save();
  outputPdf.dispose();
  return Uint8List.fromList(resultBytes);
}


// Isolate-compatible wrapper
Future<Uint8List> mergePDFsIsolate(Map<String, List<String>> args) async {
  final filePaths = args['filePaths']!;
  return await mergePDFs(filePaths);
}
