
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blue_pdf/state_providers.dart';

class SavePdfOverlay extends ConsumerStatefulWidget {
  final Uint8List pdfBytes;
  final String cachePath;

  const SavePdfOverlay({super.key, required this.pdfBytes, required this.cachePath});

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

    // 1. Show a loading indicator immediately for better UX
    showDialog(
      context: context,
      barrierDismissible: false, // User cannot dismiss the dialog by tapping outside
      builder: (BuildContext context) {
        return const Dialog(
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
        );
      },
    );

    try {
      // 2. Create the two independent save operations as Futures
      final saveToPublicFuture = _saveToPublicDownloads(filename, widget.pdfBytes);

      // 3. Run them concurrently and wait for both to complete
      final results = await Future.wait([
        saveToPublicFuture,
      ]);

      // 4. Get the results
      final publicPath = results[0]; // Path from public save

      // 5. Update all Riverpod state providers at once
      ref.read(savePathProvider.notifier).state = publicPath;
      ref.read(cachePathProvider.notifier).state = widget.cachePath;

      final currentList = ref.read(recentFilesProvider);
      if (publicPath != null && !currentList.contains(publicPath)) {
        ref.read(recentFilesProvider.notifier).state = [...currentList, publicPath];
      }

      // 6. Dismiss loading dialog and pop the screen on success
      if (mounted) {
        Navigator.pop(context); // Dismiss the loading dialog
        Navigator.pop(context, true); // Go back from the save screen
      }

    } catch (e) {
      print("❌ Exception during save: $e");
      if (mounted) {
        Navigator.pop(context); // Dismiss the loading dialog on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to save file: $e")),
        );
      }
    }
  }

  /// Helper function to save the file to the public 'Download' folder.
  /// Returns the public file path.
  Future<String?> _saveToPublicDownloads(String filename, Uint8List bytes) async {
    final String finalFilename = filename.endsWith('.pdf') ? filename : '$filename.pdf';
    return await FileSaver.instance.saveAs(
      name: finalFilename.replaceAll(".pdf", ""),
      ext: "pdf",
      bytes: bytes,
      mimeType: MimeType.pdf,
    );
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
