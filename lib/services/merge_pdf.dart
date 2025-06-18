import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';


Future<Uint8List> mergePDFs(List<String> filePaths) async {
  final outputPdf = PdfDocument();

  for (final path in filePaths) {
    final bytes = File(path).readAsBytesSync();
    final doc = PdfDocument(inputBytes: bytes);
    for (int i = 0; i < doc.pages.count; i++) {
      outputPdf.pages.add().graphics.drawPdfTemplate(
        doc.pages[i].createTemplate(),
        const Offset(0, 0),
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
