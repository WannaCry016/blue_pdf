import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavePdfOverlay extends ConsumerStatefulWidget {
  final Uint8List pdfBytes;

  const SavePdfOverlay({super.key, required this.pdfBytes});

  @override
  ConsumerState<SavePdfOverlay> createState() => _SavePdfOverlayState();
}

class _SavePdfOverlayState extends ConsumerState<SavePdfOverlay> {
  final TextEditingController _filenameController = TextEditingController(text: "merged.pdf");
  String? selectedDirectory;

  @override
  void initState() {
    super.initState();
    _loadPreviousDirectory();
  }

  Future<void> _loadPreviousDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('lastSavedDirectory');
    if (savedPath != null && await Directory(savedPath).exists()) {
      setState(() {
        selectedDirectory = savedPath;
      });
    }
  }

  Future<void> _pickDirectory() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) {
      selectedDirectory = dir;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastSavedDirectory', dir);
      setState(() {});
    }
  }

  Future<void> _saveFile() async {
    if (selectedDirectory == null || _filenameController.text.trim().isEmpty) return;

    final outputPath = '${selectedDirectory!}/${_filenameController.text.trim()}';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(widget.pdfBytes);

    // ✅ Store in global app state
    ref.read(savePathProvider.notifier).state = outputPath;

    if (mounted) {
      Navigator.pop(context); // Close bottom sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.25,
      maxChildSize: 0.5,
      builder: (_, controller) => Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: ListView(
          controller: controller,
          children: [
            const Text("📥 Save PDF File", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _filenameController,
              decoration: const InputDecoration(
                labelText: "File Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _pickDirectory,
              icon: const Icon(Icons.folder_open),
              label: Text(selectedDirectory ?? "Select Destination Folder"),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saveFile,
              icon: const Icon(Icons.save),
              label: const Text("Save"),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            ),
          ],
        ),
      ),
    );
  }
}
