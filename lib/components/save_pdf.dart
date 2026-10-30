import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

const Color kDarkCard = Color(0xFF1A2236);
const Color kDarkBorder = Color(0xFF232A3B);
const Color kDarkPrimary = Color(0xFF2979FF);
const Color kDarkAccent = Color(0xFF536DFE);
const Color kDarkTeal = Color(0xFF00B8D4);
const Color kDarkText = Colors.white;
const Color kDarkSecondaryText = Color(0xFFB0B8C1);

/// Result of a successful save.
class SavedPdf {
  const SavedPdf({required this.location, required this.localPath, required this.fileName});

  /// What the system picker returned (a `content://` URI on Android).
  final String location;

  /// Copy kept in the app cache for preview and sharing.
  final String localPath;

  final String fileName;
}

/// Bottom sheet that names the result and saves it through the system picker.
/// Pops with a [SavedPdf], or null when the user backs out.
class SavePdfOverlay extends StatefulWidget {
  const SavePdfOverlay({super.key, required this.sourcePath});

  final String sourcePath;

  @override
  State<SavePdfOverlay> createState() => _SavePdfOverlayState();
}

class _SavePdfOverlayState extends State<SavePdfOverlay> {
  static const _lastLocationKey = 'last_save_location';

  late final TextEditingController _filenameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    _filenameController = TextEditingController(text: 'bluepdf_$timestamp');
  }

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  /// File name without characters that storage providers reject.
  String _baseName() {
    var name = _filenameController.text.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (name.toLowerCase().endsWith('.pdf')) name = name.substring(0, name.length - 4);
    return name.trim();
  }

  Future<void> _saveFile() async {
    final baseName = _baseName();
    if (baseName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a file name.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final location = await FileSaver.instance.saveAs(
        name: baseName,
        filePath: widget.sourcePath,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
        initialDirectory: prefs.getString(_lastLocationKey),
      );
      if (location == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      await prefs.setString(_lastLocationKey, location);

      final fileName = '$baseName.pdf';
      final localPath = p.join(p.dirname(widget.sourcePath), fileName);
      await File(widget.sourcePath).rename(localPath);

      if (!mounted) return;
      Navigator.pop(context, SavedPdf(location: location, localPath: localPath, fileName: fileName));
    } catch (e) {
      debugPrint('Save failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("The file couldn't be saved. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? kDarkCard : Colors.white;
    final borderColor = isDark ? kDarkBorder : Colors.grey.shade300;
    final textColor = isDark ? kDarkText : Colors.black87;
    final secondaryTextColor = isDark ? kDarkSecondaryText : Colors.grey.shade600;
    final accent = isDark ? kDarkAccent : const Color(0xFF1976D2);
    final buttonGradient = isDark
        ? [kDarkPrimary, kDarkAccent, kDarkTeal]
        : [const Color(0xFF0D47A1), const Color(0xFF1976D2)];

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
              color: isDark ? kDarkPrimary.withValues(alpha: 0.13) : Colors.black12,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '📥 Save PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _filenameController,
              enabled: !_saving,
              style: TextStyle(color: textColor),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveFile(),
              decoration: InputDecoration(
                labelText: 'File Name',
                labelStyle: TextStyle(color: secondaryTextColor),
                suffixText: '.pdf',
                border: const OutlineInputBorder(),
                isDense: true,
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent),
                    ),
                    child: Text('Cancel', style: TextStyle(color: accent)),
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
                          color: isDark ? kDarkTeal.withValues(alpha: 0.18) : Colors.blue.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveFile,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save, color: Colors.white),
                      label: const Text('Save', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
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
