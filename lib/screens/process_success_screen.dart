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
    final bgColor = isDark ? Colors.grey[900] : const Color(0xFFEEEEF0);
    final textColor = isDark ? Colors.white : Colors.black87;

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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromARGB(255, 6, 42, 71), Color(0xFF64B5F6)],
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
                        colors: [Colors.blue.shade600, Colors.indigo.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: const Icon(Icons.celebration_rounded, size: 64, color: Colors.white),
                  ),

                  const SizedBox(height: 24),

                  // ✅ Headline
                  Text(
                    "File Ready 🎉",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Thanks for using Blue PDF!\nYour file is ready to go and saved securely.",
                    style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.8)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "“Great things happen when you're organized.”",
                    style: TextStyle(
                      fontSize: 13.5,
                      fontStyle: FontStyle.italic,
                      color: textColor.withOpacity(0.55),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 28),

                  // 📄 File Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 30, color: Colors.redAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.resultPath,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fileSize,
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 🔁 Preview + Share
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text("Preview", style: TextStyle(fontSize: 15)),
                          onPressed: () async {
                            final file = File(cachePath);

                            if (await file.exists()) {
                              final result = await OpenFilex.open(
                                file.path,
                                type: "application/pdf",
                              );

                              if (result.type != ResultType.done) {
                                print('❌ Could not open file: ${result.message}');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Failed to open PDF viewer.")),
                                );
                              }
                            } else {
                              print('❌ Preview file missing: ${file.path}');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("File not found in cache.")),
                              );
                            }
                          },

                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text("Share", style: TextStyle(fontSize: 15)),
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
                                print('❌ Share failed: $e');
                              }
                            } else {
                              print('❌ Cache file not found: ${file.path}');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ⬅️ Back to Home
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.home),
                      label: const Text("Back to Home", style: TextStyle(fontSize: 16)),
                      onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.grey.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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