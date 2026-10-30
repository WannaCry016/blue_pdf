import 'dart:io';
import 'package:flutter/material.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:share_plus/share_plus.dart';
import 'about_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import '../components/brand_title.dart';
import '../components/save_pdf.dart' show SavedPdf;
import '../utils/cache_cleaner.dart';
import '../pdf/pdf_engine.dart';
import '../utils/saved_location.dart';

// Responsive helper: returns true if device is a tablet (width > 600dp)
bool isTablet(BuildContext context) {
  final width = MediaQuery.of(context).size.shortestSide;
  return width >= 600;
}

class ProcessSuccessScreen extends ConsumerStatefulWidget {
  final SavedPdf saved;

  const ProcessSuccessScreen({super.key, required this.saved});

  @override
  ConsumerState<ProcessSuccessScreen> createState() => _ProcessSuccessScreenState();
}

class _FileDetails {
  const _FileDetails(this.name, this.subtitle);
  final String name;
  final String subtitle;
}

class _ProcessSuccessScreenState extends ConsumerState<ProcessSuccessScreen> {
  late final Future<_FileDetails> _details = _loadDetails();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mergePdfFilesProvider.notifier).clear();
      ref.read(imageToPdfFilesProvider.notifier).clear();
      ref.read(encryptPdfFilesProvider.notifier).clear();
      ref.read(splitPdfFilesProvider.notifier).clear();
      ref.read(reorderPdfFilesProvider.notifier).clear();
    });
  }

  /// The picker lets the user rename the file and Downloads saves clashes as
  /// "name (1).pdf", so ask the provider for the real name first.
  Future<_FileDetails> _loadDetails() async {
    final saved = widget.saved;
    SavedDocument document = const SavedDocument();
    try {
      document = await PdfEngine.describeSaved(saved.location);
    } catch (e) {
      debugPrint('Could not describe saved file: $e');
    }
    final name = document.name ?? saved.fileName;
    int? size = document.size;
    if (size == null) {
      try {
        size = await File(saved.localPath).length();
      } catch (_) {}
    }
    final folder = saved.folder ?? savedFolder(saved.location);
    final parts = [
      if (size != null) formatFileSize(size),
      if (folder != null) 'Saved to $folder',
    ];
    return _FileDetails(name, parts.isEmpty ? 'Saved' : parts.join('  •  '));
  }

  @override
  void dispose() {
    // The job is done and saved, so its inputs, result and thumbnails can go.
    clearCache(before: DateTime.now()).ignore();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTab = isTablet(context);
    final bgColor = isDark ? const Color(0xFF101A30) : const Color(0xFFEEEEF0);
    final cardColor = isDark ? const Color(0xFF1A2236) : Colors.white;
    final borderColor = isDark ? const Color(0xFF232A3B) : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? const Color(0xFFB0B8C1) : Colors.grey;
    final accent = isDark ? const Color(0xFF2979FF) : const Color(0xFF1976D2);
    final gradientColors = isDark
        ? [const Color(0xFF2979FF), const Color(0xFF536DFE), const Color(0xFF00B8D4)]
        : [const Color(0xFF0D47A1), const Color(0xFF1976D2)];

    final localPath = widget.saved.localPath;

    // Responsive sizes
    final double mainFont = isTab ? 36 : 28;
    final double subFont = isTab ? 22 : 16;
    final double quoteFont = isTab ? 18 : 13.5;
    final double cardFont = isTab ? 20 : 14.5;
    final double fileSizeFont = isTab ? 17 : 13;
    final double iconSize = isTab ? 48 : 32;
    final double celebrationIcon = isTab ? 110 : 68;
    final double celebrationPad = isTab ? 44 : 28;
    final double cardPad = isTab ? 32 : 18;
    final double cardRadius = isTab ? 22 : 14;
    final double buttonFont = isTab ? 22 : 16;
    final double buttonPad = isTab ? 24 : 16;
    final double buttonIcon = isTab ? 32 : 22;
    final double contentMaxWidth = isTab ? 600 : double.infinity;
    final double contentPad = isTab ? 48 : 24;
    final double vSpace = isTab ? 44 : 28;
    final double hButtonSpace = isTab ? 32 : 16;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: isTab ? 70 : 50,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        automaticallyImplyLeading: false,
        title: isTab ? const BrandTitle(logoSize: 40, fontSize: 28) : const BrandTitle(),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: "About Developer",
            icon: Icon(Icons.info_outline, color: Colors.white, size: isTab ? 30 : 22),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(contentPad),
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    children: [
                      // 🎉 Celebration Icon
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? accent.withValues(alpha: 0.18) : Colors.blue.withValues(alpha: 0.18),
                              blurRadius: isTab ? 28 : 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(celebrationPad),
                        child: Icon(Icons.celebration_rounded, size: celebrationIcon, color: Colors.white),
                      ),

                      SizedBox(height: vSpace),

                      // ✅ Headline
                      Text(
                        "File Ready 🎉",
                        style: TextStyle(fontSize: mainFont, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.2),
                      ),
                      SizedBox(height: isTab ? 20 : 12),
                      Text(
                        "Thanks for using Blue PDF!\nYour file is ready to go and saved securely.",
                        style: TextStyle(fontSize: subFont, color: secondaryTextColor, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isTab ? 18 : 14),
                      Text(
                        "“Great things happen when you're organized.”",
                        style: TextStyle(
                          fontSize: quoteFont,
                          fontStyle: FontStyle.italic,
                          color: secondaryTextColor.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: isTab ? 40 : 32),

                      // 📄 File Info Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(cardPad),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(cardRadius),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black26 : Colors.black12,
                              blurRadius: isTab ? 14 : 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf, size: iconSize, color: Colors.redAccent),
                            SizedBox(width: isTab ? 24 : 14),
                            Expanded(
                              child: FutureBuilder<_FileDetails>(
                                future: _details,
                                builder: (context, snapshot) {
                                  final details = snapshot.data;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        details?.name ?? widget.saved.fileName,
                                        style: TextStyle(
                                          fontSize: cardFont,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                        maxLines: isTab ? 3 : 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: isTab ? 8 : 4),
                                      Text(
                                        details?.subtitle ?? '',
                                        style: TextStyle(fontSize: fileSizeFont, color: secondaryTextColor),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: vSpace),

                      // 🔁 Preview + Share
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(cardRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark 
                                      ? accent.withValues(alpha: 0.13) 
                                      : Colors.blue.withValues(alpha: 0.08),
                                    blurRadius: isTab ? 12 : 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                // Add subtle border for light theme
                                border: isDark 
                                  ? null 
                                  : Border.all(color: Colors.blue.withValues(alpha: 0.1), width: 0.5),
                              ),
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: buttonIcon),
                                label: Text("Preview", style: TextStyle(fontSize: buttonFont, color: Colors.white, fontWeight: FontWeight.w500)),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final file = File(localPath);
                                  if (!await file.exists()) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text("The preview copy is no longer available.")),
                                    );
                                    return;
                                  }
                                  final result = await OpenFilex.open(file.path, type: "application/pdf");
                                  if (result.type != ResultType.done) {
                                    debugPrint('Could not open file: ${result.message}');
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text("No app is available to open PDFs.")),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.symmetric(vertical: buttonPad),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: hButtonSpace),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(cardRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark 
                                      ? accent.withValues(alpha: 0.13) 
                                      : Colors.blue.withValues(alpha: 0.08),
                                    blurRadius: isTab ? 12 : 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                // Add subtle border for light theme
                                border: isDark 
                                  ? null 
                                  : Border.all(color: Colors.blue.withValues(alpha: 0.1), width: 0.5),
                              ),
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.share, color: Colors.white, size: buttonIcon),
                                label: Text("Share", style: TextStyle(fontSize: buttonFont, color: Colors.white, fontWeight: FontWeight.w500)),
                                onPressed: () async {
                                  final file = File(localPath);
                                  if (!await file.exists()) return;
                                  try {
                                    await SharePlus.instance.share(
                                      ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')]),
                                    );
                                  } catch (e) {
                                    debugPrint('Share failed: $e');
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.symmetric(vertical: buttonPad),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: vSpace),

                      // ⬅️ Back to Home
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(cardRadius),
                            boxShadow: [
                              BoxShadow(
                                color: isDark 
                                  ? accent.withValues(alpha: 0.13) 
                                  : Colors.blue.withValues(alpha: 0.08),
                                blurRadius: isTab ? 12 : 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            // Add subtle border for light theme
                            border: isDark 
                              ? null 
                              : Border.all(color: Colors.blue.withValues(alpha: 0.1), width: 0.5),
                          ),
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.home, color: Colors.white, size: buttonIcon),
                            label: Text("Back to Home", style: TextStyle(fontSize: buttonFont, color: Colors.white, fontWeight: FontWeight.w500)),
                            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(vertical: buttonPad + 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      )

    );
  }
}