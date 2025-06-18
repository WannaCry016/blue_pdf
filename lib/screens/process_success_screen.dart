import 'dart:io';
import 'package:blue_pdf/screens/pdf_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:blue_pdf/main.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:share_plus/share_plus.dart';
import 'about_page.dart';  // adjust as per your project structure
import 'package:flutter_riverpod/flutter_riverpod.dart';


class ProcessSuccessScreen extends ConsumerWidget {
  final String resultPath;

  const ProcessSuccessScreen({super.key, required this.resultPath});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900] : const Color(0xFFEEEEF0);
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? Colors.grey[850] : Colors.grey[100];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mergePdfFilesProvider.notifier).clear();
      ref.read(imageToPdfFilesProvider.notifier).clear();
    });

    final fileSize = _getFileSize(resultPath);

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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: IconButton(
              key: ValueKey(themeNotifier.value),
              tooltip: "Toggle Theme",
              icon: Icon(
                themeNotifier.value == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () async {
                final newTheme = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                themeNotifier.value = newTheme;
                await ThemePrefs.saveThemeMode(newTheme);
              },
            ),
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

                  const SizedBox(height: 20),

                  const SizedBox(height: 20),

                  /// PDF Info Box (Clickable)
                  GestureDetector(
                    onTap: () {
                      ref.read(selectedFilePathProvider.notifier).state = resultPath;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PdfViewerScreen(), // 👈 no arguments passed
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.picture_as_pdf, size: 30, color: Colors.blueAccent),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  resultPath.split("/").last,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fileSize,
                                  style: TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  /// Action Buttons: Back to Home + Share
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.home),
                          label: const Text("Home", style: TextStyle(fontSize: 15)),
                          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.grey.shade800,
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
                          onPressed: () {
                            Share.shareXFiles([XFile(resultPath)], text: 'Here is your PDF');
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),



                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}