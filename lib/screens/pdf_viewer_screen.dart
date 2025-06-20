import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfPreviewScreen extends StatelessWidget {
  final String path;
  const PdfPreviewScreen({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Preview PDF")),
      body: PDFView(
        filePath: path,
        autoSpacing: true,
        swipeHorizontal: false,
        pageSnap: true,
        onError: (e) => print("❌ PDF Error: $e"),
      ),
    );
  }
}
