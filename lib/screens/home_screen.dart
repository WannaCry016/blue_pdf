import 'dart:io';
import 'dart:ui';
import 'package:blue_pdf/screens/pdf_viewer_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'camera.dart';
import 'dropdown.dart';
import 'process_success_screen.dart';
import 'about_page.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:blue_pdf/main.dart';
import 'save_pdf.dart';
import 'package:blue_pdf/services/image_to_pdf.dart';
import 'package:blue_pdf/services/merge_pdf.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  void _processFiles() async {
    final selectedTool = ref.read(selectedToolProvider);

    // Get correct file list based on selected tool
    final selectedFiles = selectedTool == 'Merge PDF'
        ? ref.read(mergePdfFilesProvider)
        : ref.read(imageToPdfFilesProvider);

    if (selectedTool == null || selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select tool and files first.")),
      );
      return;
    }

    ref.read(isProcessingProvider.notifier).state = true;
    await Future.delayed(Duration.zero); // Let UI update before heavy work

    try {
      String? outputPath;
      String? cachePath;
      Uint8List resultBytes;

      final filePaths = selectedFiles.map((f) => f.path!).toList();

      if (selectedTool == 'Merge PDF') {
        resultBytes = await compute(
          mergePDFsIsolate as ComputeCallback<Map<String, List<String>>, Uint8List>,
          {'filePaths': filePaths},
        );
      } else {
        resultBytes = await compute(
          imageToPdf as ComputeCallback<Map<String, List<String>>, Uint8List>,
          {'filePaths': filePaths},
        );
      }

      // Store result in memory
      ref.read(mergedPdfBytesProvider.notifier).state = resultBytes;
      ref.read(isProcessingProvider.notifier).state = false;

      // Show save overlay
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SavePdfOverlay(pdfBytes: resultBytes),
      );

      outputPath = ref.read(savePathProvider);
      cachePath = ref.read(cachePathProvider);
      final recent = ref.read(recentFilesProvider);
      final updated = [outputPath, ...recent].toSet().toList();
      ref.read(recentFilesProvider.notifier).state =
          updated.cast<String>().take(4).toList();
        

      // Navigate to success screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProcessSuccessScreen(resultPath: outputPath!, cachePath: cachePath!),
        ),
      );
    } catch (e) {
      print("Error: ${e.toString()}");
    } finally {
      ref.read(isProcessingProvider.notifier).state = false;
    }
  }


  void _onToolSelect() async {
    try {
      final selectedTool = ref.read(selectedToolProvider);

      if (selectedTool == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select a tool.")),
        );
        ref.read(isFileLoadingProvider.notifier).state = false;
        return;
      }

      FilePickerResult? result;

      switch (selectedTool) {
        case 'Merge PDF':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            allowMultiple: true,
            withData: false,
          );
          if (result != null && result.files.isNotEmpty) {
            ref.read(isFileLoadingProvider.notifier).state = true;
            ref.read(mergePdfFilesProvider.notifier).addFiles(result.files);
          }
          break;

        case 'Image to PDF':
          result = await FilePicker.platform.pickFiles(
            type: FileType.image, 
            allowMultiple: true,
            withData: false,
          );
          if (result != null && result.files.isNotEmpty) {
            ref.read(imageToPdfFilesProvider.notifier).addFiles(result.files);
          }
          break;
      }
    } catch (e, stackTrace) {
      debugPrint("Error during tool selection: $e");
      debugPrint("StackTrace: $stackTrace");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Something went wrong while picking files.")),
      );
    } finally {
      ref.read(isFileLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {

    var selectedTool = ref.watch(selectedToolProvider);

    final filesNotifier = selectedTool == 'Merge PDF'
      ? ref.read(mergePdfFilesProvider.notifier)
      : ref.read(imageToPdfFilesProvider.notifier);

    final selectedFiles = selectedTool == 'Merge PDF'
        ? ref.watch(mergePdfFilesProvider)
        : ref.watch(imageToPdfFilesProvider);

    final isLoading = ref.watch(isFileLoadingProvider);
    var recentFiles = ref.watch(recentFilesProvider);
    var isProcessing = ref.watch(isProcessingProvider);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? const Color(0xFF121212) :const Color(0xFFECEFF1);

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
          Icons.picture_as_pdf, // Flutter built-in PDF-looking icon
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AboutPage()),
              );
            },
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: IconButton(
              key: ValueKey(themeNotifier.value),
              tooltip: "Toggle Theme",
              icon: Icon(
                themeNotifier.value == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () async {
                final newTheme = themeNotifier.value == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark;
                themeNotifier.value = newTheme;
                await ThemePrefs.saveThemeMode(newTheme);
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                if (selectedTool == null) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: const Text("Tool Not Selected"),
                      content: const Text(
                        "Please select a tool before choosing a file.",
                        style: TextStyle(fontSize: 15),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("OK", style: TextStyle(color: Color(0xFFFF6F00))), // Bright Orange
                        )
                      ],
                    ),
                  );
                  return;
                }
                _onToolSelect(); 
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(vertical: 26),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(255, 11, 55, 106), // deeper blue
                      Color(0xFF42A5F5), // lighter blue
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.upload_file_rounded, color: Colors.white, size: 26),
                    SizedBox(width: 10),
                    Text(
                      "Select File",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

            ),

          if (isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  Text(
                    "Selected Files",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)), // deep blue
                    ),
                  ),
                ],
              ),
            )

          else if (selectedFiles.isEmpty)
            Text(
              "Upload a file to begin. Supported: PDF, JPG, PNG.",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            )

          else
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Selected Files",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    constraints: const BoxConstraints(
                      maxHeight: 210,
                    ),
                    child: Scrollbar(
                      thumbVisibility: true,
                      radius: const Radius.circular(8),
                      thickness: 3,
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        itemCount: selectedFiles.length,
                        onReorder: (oldIndex, newIndex) {
                          filesNotifier.reorder(oldIndex, newIndex);
                        },
                        padding: EdgeInsets.zero,
                        buildDefaultDragHandles: true,
                        itemBuilder: (context, index) {
                          final file = selectedFiles[index];

                          IconData iconData;
                          Color iconColor;

                          if (file.extension == 'pdf') {
                            iconData = Icons.picture_as_pdf_rounded;
                            iconColor = Colors.blueAccent;
                          } else {
                            iconData = Icons.image_outlined;
                            iconColor = Colors.teal;
                          }

                          return ListTile(
                            key: ValueKey(file.path),
                            dense: true,
                            visualDensity: const VisualDensity(vertical: -4),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            leading: Icon(iconData, color: iconColor, size: 22),
                            title: Text(
                              file.name,
                              style: TextStyle(fontSize: 14.5, color: textColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: GestureDetector(
                              onTap: () {
                                filesNotifier.removeFileAt(index);
                              },
                              child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                            ),
                            onTap: () async {
                              final filePath = file.path!;
                              ref.read(selectedFilePathProvider.notifier).state = filePath;

                              if (file.extension == 'pdf') {
                                await OpenFilex.open(filePath);
                              } else if (['jpg', 'jpeg', 'png', 'gif'].contains(file.extension!.toLowerCase())) {
                                await OpenFilex.open(filePath);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Unsupported file type.")),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),


                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isProcessing ? 160 : 140,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: _processFiles,
                          child: Center(
                            child: isProcessing
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text("Processing", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.play_arrow_rounded, size: 22, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        "Process",
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),


            const SizedBox(height: 25),

            CustomDropdown(
              selectedTool: selectedTool,
              onChanged: (val) {
                ref.read(selectedToolProvider.notifier).state = val;
              },
              isDark: isDark,
              textColor: textColor,
            ),

            const SizedBox(height: 36),
            
            const SizedBox(height: 25),
            Flexible(
              child: Align(
                alignment: Alignment.topCenter,
                child: selectedFiles.isEmpty
                    ? Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blueGrey.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Image.asset(
                                'assets/4.jpg',
                                height: 150,
                                width: 150,
                                fit: BoxFit.contain,
                              ),
                            const SizedBox(height: 12),
                            Text(
                              "Start by choosing a tool or uploading a file.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: textColor.withOpacity(0.55),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      )
                    : const SizedBox(height:10)
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: CameraButton(),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
