import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../pdf/pdf_engine.dart';
import '../utils/pdf_saver.dart';

const Color kDarkCard = Color(0xFF1A2236);
const Color kDarkBorder = Color(0xFF232A3B);
const Color kDarkPrimary = Color(0xFF2979FF);
const Color kDarkAccent = Color(0xFF536DFE);
const Color kDarkTeal = Color(0xFF00B8D4);
const Color kDarkText = Colors.white;
const Color kDarkSecondaryText = Color(0xFFB0B8C1);

/// Result of a successful save.
class SavedPdf {
  const SavedPdf({required this.location, required this.localPath, required this.fileName, this.folder});

  /// Where it was saved: a `content://` URI on Android.
  final String location;

  /// Copy kept in the app cache for preview and sharing.
  final String localPath;

  final String fileName;

  /// Human-readable folder when the app chose it, e.g. `Download/BLUE PDF`.
  final String? folder;
}

/// Bottom sheet that names the result and saves it, either straight into the
/// app's folder in Downloads or wherever the user picks.
///
/// On success it replaces itself with the page built by [next], so there is
/// no flash of the screen underneath, and completes with the [SavedPdf].
/// Completes with null when the user backs out.
class SavePdfOverlay extends StatefulWidget {
  const SavePdfOverlay({
    super.key,
    required this.sourcePath,
    required this.next,
    this.canUseAppFolder = false,
    this.useAppFolder = true,
    this.saver = const PdfSaver(),
  });

  final String sourcePath;
  final Widget Function(SavedPdf saved) next;

  /// False where saving to Downloads would need a storage permission.
  final bool canUseAppFolder;

  /// Initial state of the "Save to Download/BLUE PDF" option.
  final bool useAppFolder;

  final PdfSaver saver;

  static const _useAppFolderKey = 'save_to_app_folder';

  static Future<SavedPdf?> show(
    BuildContext context, {
    required String sourcePath,
    required Widget Function(SavedPdf saved) next,
    PdfSaver saver = const PdfSaver(),
  }) async {
    // Both are near-instant; reading them first avoids the sheet changing size as it opens.
    final (canUseAppFolder, prefs) = await (PdfEngine.canSaveToDownloads(), SharedPreferences.getInstance()).wait;
    if (!context.mounted) return null;
    return showModalBottomSheet<SavedPdf>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SavePdfOverlay(
        sourcePath: sourcePath,
        next: next,
        canUseAppFolder: canUseAppFolder,
        useAppFolder: prefs.getBool(_useAppFolderKey) ?? true,
        saver: saver,
      ),
    );
  }

  @override
  State<SavePdfOverlay> createState() => _SavePdfOverlayState();
}

class _SavePdfOverlayState extends State<SavePdfOverlay> {
  static const _lastLocationKey = 'last_save_location';

  late final TextEditingController _filenameController;
  late bool _useAppFolder = widget.useAppFolder;
  bool _saving = false;

  bool get _savesToAppFolder => widget.canUseAppFolder && _useAppFolder;

  @override
  void initState() {
    super.initState();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    _filenameController = TextEditingController(text: 'bluepdf_$timestamp');
  }

  Future<void> _setUseAppFolder(bool value) async {
    setState(() => _useAppFolder = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SavePdfOverlay._useAppFolderKey, value);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a file name.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final toAppFolder = _savesToAppFolder;
      final String? location;
      if (toAppFolder) {
        location = await widget.saver.saveToAppFolder(name: baseName, sourcePath: widget.sourcePath);
        if (location == null) throw StateError('Downloads returned no location');
      } else {
        final prefs = await SharedPreferences.getInstance();
        location = await widget.saver.saveWithPicker(
          name: baseName,
          sourcePath: widget.sourcePath,
          initialDirectory: prefs.getString(_lastLocationKey),
        );
        if (location == null) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        await prefs.setString(_lastLocationKey, location);
      }

      final fileName = '$baseName.pdf';
      final localPath = p.join(p.dirname(widget.sourcePath), fileName);
      await File(widget.sourcePath).rename(localPath);

      if (!mounted) return;
      final saved = SavedPdf(
        location: location,
        localPath: localPath,
        fileName: fileName,
        folder: toAppFolder ? PdfSaver.appFolderLabel : null,
      );
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => widget.next(saved)), result: saved);
    } catch (e) {
      debugPrint('Save failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("The file couldn't be saved. Please try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    // Without the option (Android 9 and below) "Save" opens the picker, as before.
    final optedOut = widget.canUseAppFolder && !_useAppFolder;

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
            if (widget.canUseAppFolder) ...[
              const SizedBox(height: 8),
              // Its own Material so the ripple isn't hidden behind the card's background.
              Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  value: _useAppFolder,
                  onChanged: _saving ? null : (value) => _setUseAppFolder(value ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  title: Text(
                    'Save to ${PdfSaver.appFolderLabel}',
                    style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else
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
                          : Icon(optedOut ? Icons.folder_open : Icons.save, color: Colors.white),
                      label: Text(optedOut ? 'Choose folder' : 'Save', style: const TextStyle(color: Colors.white)),
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
