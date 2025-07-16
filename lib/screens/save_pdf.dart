import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:blue_pdf/state_providers.dart';

class SavePdfOverlay extends ConsumerStatefulWidget {
  final Uint8List pdfBytes;

  const SavePdfOverlay({super.key, required this.pdfBytes});

  @override
  ConsumerState<SavePdfOverlay> createState() => _SavePdfOverlayState();
}

class _SavePdfOverlayState extends ConsumerState<SavePdfOverlay> {
  late TextEditingController _filenameController;

  @override
  void initState() {
    super.initState();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final defaultName = "bluepdf_$timestamp.pdf";
    _filenameController = TextEditingController(text: defaultName);
  }

  Future<void> _saveFile() async {
    final filename = _filenameController.text.trim();
    if (filename.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a filename.")),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Saving PDF..."),
            ],
          ),
        ),
      ),
    );

    try {
      final saveToPublicFuture = _saveToPublicDownloads(filename, widget.pdfBytes);
      final saveToCacheFuture = _saveToAppCache(filename, widget.pdfBytes);

      final results = await Future.wait([
        saveToPublicFuture,
        saveToCacheFuture,
      ]);

      final publicPath = results[0]; // From FileSaver
      final cachePath = results[1]; // From app's cache

      ref.read(savePathProvider.notifier).state = publicPath;
      ref.read(cachePathProvider.notifier).state = cachePath;

      final currentList = ref.read(recentFilesProvider);
      if (publicPath != null && !currentList.contains(publicPath)) {
        ref.read(recentFilesProvider.notifier).state = [...currentList, publicPath];
      }

      if (mounted) {
        Navigator.pop(context); // dismiss loading
        Navigator.pop(context, true); // return success
      }
    } catch (e) {
      print("❌ Exception during save: $e");
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to save file: $e")),
        );
      }
    }
  }

  Future<String?> _saveToPublicDownloads(String filename, Uint8List bytes) async {
    final String finalFilename = filename.endsWith('.pdf') ? filename : '$filename.pdf';
    return await FileSaver.instance.saveAs(
      name: finalFilename.replaceAll(".pdf", ""),
      ext: "pdf",
      bytes: bytes,
      mimeType: MimeType.pdf,
    );
  }

  Future<String> _saveToAppCache(String filename, Uint8List bytes) async {
    final cacheDir = await getTemporaryDirectory();
    final String finalFilename = filename.endsWith('.pdf') ? filename : '$filename.pdf';
    final File file = File(path.join(cacheDir.path, finalFilename));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "📥 Save PDF",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _filenameController,
              decoration: const InputDecoration(
                labelText: "File Name",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveFile,
                    icon: const Icon(Icons.save),
                    label: const Text("Save"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
