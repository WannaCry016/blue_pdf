import 'dart:io';
import 'package:flutter/material.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:share_plus/share_plus.dart';
import 'about_page.dart';  // adjust as per your project structure
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';


class ProcessSuccessScreen extends ConsumerStatefulWidget {
  final String resultPath;

  const ProcessSuccessScreen({super.key, required this.resultPath});

  @override
  ConsumerState<ProcessSuccessScreen> createState() => _ProcessSuccessScreenState();
}

class _ProcessSuccessScreenState extends ConsumerState<ProcessSuccessScreen> {
  @override
  void dispose() {
    _clearAppCache();
    super.dispose();
  }

  void _clearAppCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();

      if (await cacheDir.exists()) {
        final files = cacheDir.listSync();
        for (final file in files) {
          try {
            if (file is File || file is Directory) {
              await file.delete(recursive: true);
            }
          } catch (e) {
            print("⚠️ Error deleting ${file.path}: $e");
          }
        }
        print("🧹 Cache directory cleared: ${cacheDir.path}");
      }
    } catch (e) {
      print("❌ Failed to clear cache: $e");
    }
  }


  String _getFileSize(String path) {
    try {
      final file = File(path);
      final sizeInBytes = file.lengthSync();
      final sizeInKB = (sizeInBytes / 1024).toStringAsFixed(1);
      return "$sizeInKB KB";
    } catch (_) {
      return "Unknown Size";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101A30) : const Color(0xFFEEEEF0);
    final cardColor = isDark ? const Color(0xFF1A2236) : Colors.white;
    final borderColor = isDark ? const Color(0xFF232A3B) : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? const Color(0xFFB0B8C1) : Colors.grey;
    final accent = isDark ? const Color(0xFF2979FF) : const Color(0xFF1976D2);
    final gradientColors = isDark
        ? [const Color(0xFF2979FF), const Color(0xFF536DFE), const Color(0xFF00B8D4)]
        : [const Color(0xFF0D47A1), const Color(0xFF1976D2)];

    final cachePath = ref.watch(cachePathProvider)!;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mergePdfFilesProvider.notifier).clear();
      ref.read(imageToPdfFilesProvider.notifier).clear();
      ref.read(encryptPdfFilesProvider.notifier).clear();
      ref.read(unlockPdfFilesProvider.notifier).clear();
    });

    final fileSize = _getFileSize(widget.resultPath);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 50,
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
        leading: const Icon(
          Icons.picture_as_pdf,
          color: Colors.white,
          size: 26,
        ),
        title: const Text(
          "BLUE PDF",
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: "About Developer",
            icon: const Icon(Icons.info_outline, color: Colors.white, size: 22),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
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
                          color: isDark ? accent.withOpacity(0.18) : Colors.blue.withOpacity(0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(28),
                    child: const Icon(Icons.celebration_rounded, size: 68, color: Colors.white),
                  ),

                  const SizedBox(height: 28),

                  // ✅ Headline
                  Text(
                    "File Ready 🎉",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Thanks for using Blue PDF!\nYour file is ready to go and saved securely.",
                    style: TextStyle(fontSize: 16, color: secondaryTextColor, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "“Great things happen when you're organized.”",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                      color: secondaryTextColor.withOpacity(0.7),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // 📄 File Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black26 : Colors.black12,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 32, color: Colors.redAccent),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.resultPath,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fileSize,
                                style: TextStyle(fontSize: 13, color: secondaryTextColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

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
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? accent.withOpacity(0.13) : Colors.blue.withOpacity(0.13),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                            label: const Text("Preview", style: TextStyle(fontSize: 15, color: Colors.white)),
                            onPressed: () async {
                              final file = File(cachePath);

                              if (await file.exists()) {
                                final result = await OpenFilex.open(
                                  file.path,
                                  type: "application/pdf",
                                );

                                if (result.type != ResultType.done) {
                                  print('❌ Could not open file: \\${result.message}');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Failed to open PDF viewer.")),
                                  );
                                }
                              } else {
                                print('❌ Preview file missing: \\${file.path}');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("File not found in cache.")),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: isDark ? accent.withOpacity(0.13) : Colors.blue.withOpacity(0.13),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.share, color: Colors.white),
                            label: const Text("Share", style: TextStyle(fontSize: 15, color: Colors.white)),
                            onPressed: () async {
                              final file = File(cachePath);
                              if (await file.exists()) {
                                try {
                                  await SharePlus.instance.share(
                                    ShareParams(
                                      files: [XFile(file.path, mimeType: 'application/pdf')],
                                    ),
                                  );
                                } catch (e) {
                                  print('❌ Share failed: \\${e}');
                                }
                              } else {
                                print('❌ Cache file not found: \\${file.path}');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

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
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? accent.withOpacity(0.13) : Colors.blue.withOpacity(0.13),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.home, color: Colors.white),
                        label: const Text("Back to Home", style: TextStyle(fontSize: 16, color: Colors.white)),
                        onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      )

    );
  }
}