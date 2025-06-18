import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blue_pdf/state_providers.dart';

class SavePdfOverlay extends ConsumerStatefulWidget {
  final Uint8List pdfBytes;

  const SavePdfOverlay({super.key, required this.pdfBytes});

  @override
  ConsumerState<SavePdfOverlay> createState() => _SavePdfOverlayState();
}

class _SavePdfOverlayState extends ConsumerState<SavePdfOverlay> {
  final TextEditingController _filenameController = TextEditingController(text: "merged.pdf");

  Future<void> _saveFile() async {
    final filename = _filenameController.text.trim();
    if (filename.isEmpty) return;

    try {
      final res = await FileSaver.instance.saveFile(
        name: filename.replaceAll(".pdf", ""),
        bytes: widget.pdfBytes,
        ext: "pdf",
        mimeType: MimeType.pdf,
      );

      ref.read(savePathProvider.notifier).state = res;
      if (mounted) Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed to save: $e")),
      );
    }
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
                    onPressed: () => Navigator.pop(context),
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
