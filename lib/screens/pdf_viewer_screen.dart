import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfPreviewScreen extends StatelessWidget {
  final String path;
  const PdfPreviewScreen({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Preview PDF")),
      body: SfPdfViewer.file(
        File(path),
        canShowScrollStatus: false,
        canShowPaginationDialog: false,
        pageSpacing: 0,
        scrollDirection: PdfScrollDirection.vertical,
        pageLayoutMode: PdfPageLayoutMode.single,
      ),
    );
  }
}
