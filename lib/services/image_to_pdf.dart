import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:io';

Future<Uint8List> imageToPdf(Map<String, List<String>> args) async {
  final filePaths = args['filePaths']!;
  final pdf = pw.Document();

  for (final path in filePaths) {
    final image = File(path).readAsBytesSync();
    final imageProvider = pw.MemoryImage(image);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(
              imageProvider,
              fit: pw.BoxFit.contain,
              width: PdfPageFormat.a4.availableWidth,
              height: PdfPageFormat.a4.availableHeight,
            ),
          );
        },
      ),
    );

  }

  return pdf.save();
}
