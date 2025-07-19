import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:blue_pdf/state_providers.dart';

// Add dark theme color palette
const Color kDarkBg = Color(0xFF101A30);         // Deep navy
const Color kDarkCard = Color(0xFF1A2236);       // Soft card
const Color kDarkBorder = Color(0xFF232A3B);
const Color kDarkPrimary = Color(0xFF2979FF);    // Vibrant blue
const Color kDarkAccent = Color(0xFF536DFE);     // Electric indigo
const Color kDarkTeal = Color(0xFF00B8D4);       // Teal accent
const Color kDarkText = Colors.white;
const Color kDarkSecondaryText = Color(0xFFB0B8C1);

class SavePdfOverlay extends ConsumerStatefulWidget {
  final Uint8List pdfBytes;

  const SavePdfOverlay({super.key, required this.pdfBytes});

  @override
  ConsumerState<SavePdfOverlay> createState() => _SavePdfOverlayState();
}

class _SavePdfOverlayState extends ConsumerState<SavePdfOverlay> {
  late TextEditingController _filenameController = TextEditingController();
  late TextEditingController _passwordController = TextEditingController();
  bool _encryptChecked = false;

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? kDarkCard : Colors.white;
    final borderColor = isDark ? kDarkBorder : Colors.grey.shade300;
    final textColor = isDark ? kDarkText : Colors.black87;
    final secondaryTextColor = isDark ? kDarkSecondaryText : Colors.grey.shade600;
    final buttonGradient = isDark
        ? [kDarkPrimary, kDarkAccent, kDarkTeal]
        : [Color(0xFF0D47A1), Color(0xFF1976D2)];

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: isDark ? kDarkPrimary.withOpacity(0.13) : Colors.black12,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "📥 Save PDF",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _filenameController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: "File Name",
                    labelStyle: TextStyle(color: secondaryTextColor),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? kDarkAccent : Color(0xFF1976D2)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? kDarkAccent : Color(0xFF1976D2),
                          side: BorderSide(color: isDark ? kDarkAccent : Color(0xFF1976D2)),
                        ),
                        child: Text("Cancel", style: TextStyle(color: isDark ? kDarkAccent : Color(0xFF1976D2))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: buttonGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? kDarkTeal.withOpacity(0.18) : Colors.blue.withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _saveFile,
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: const Text("Save", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            minimumSize: const Size.fromHeight(44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }, // builder
        ),
      ),
    );
  }

}
