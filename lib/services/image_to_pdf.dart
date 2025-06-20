import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> imageToPdf(Map<String, List<String>> args) async {
  final filePaths = args['filePaths']!;
  final pdf = pw.Document();

  for (final path in filePaths) {
    final bytes = File(path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) continue;

    final imageProvider = pw.MemoryImage(bytes);
    final imgW = decoded.width.toDouble();
    final imgH = decoded.height.toDouble();

    final pageW = PdfPageFormat.a4.width;
    final pageH = PdfPageFormat.a4.height;

    final imgAspect = imgW / imgH;
    final pageAspect = pageW / pageH;

    double finalW, finalH;

    if (imgAspect > pageAspect) {
      // Wider image — fill width
      finalW = pageW;
      finalH = pageW / imgAspect;
    } else {
      // Taller image — fill height
      finalH = pageH;
      finalW = pageH * imgAspect;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) {
          return pw.Center(
            child: pw.Image(
              imageProvider,
              width: finalW,
              height: finalH,
            ),
          );
        },
      ),
    );
  }

  return pdf.save();
}
