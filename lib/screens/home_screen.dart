
import 'dart:io';
import 'dart:ui';
import 'package:blue_pdf/services/pdf_encryptor.dart';
import 'package:blue_pdf/services/unlock_pdf.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'camera.dart';
import 'dropdown.dart';
import 'process_success_screen.dart';
import 'about_page.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

  final fileProviders = {
      'Merge PDF': mergePdfFilesProvider,
      'Image to PDF': imageToPdfFilesProvider,
      'Encrypt PDF': encryptPdfFilesProvider,
      'Unlock PDF': unlockPdfFilesProvider,
    };

  Future<String?> _promptPassword(BuildContext context, {required String action}) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$action PDF"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Password"),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    );
  }



  void _processFiles() async {
    final selectedTool = ref.read(selectedToolProvider);
    // Use fallback to prevent crash if tool is not in the map
    final currentProvider = fileProviders[selectedTool] ?? mergePdfFilesProvider;
    final selectedFiles = ref.read(currentProvider);

    if (selectedTool == null || selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a tool and files first.")),
      );
      return;
    }

    ref.read(isProcessingProvider.notifier).state = true;

    // === Show loading dialog immediately ===
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        backgroundColor: Colors.white,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Flexible(child: Text("Processing PDF...", style: TextStyle(fontSize: 16))),
            ],
          ),
        ),
      ),
    );

    // Let UI fully render before native call
    await Future.delayed(const Duration(milliseconds: 200));

    String? initialCachePath;

    try {
      Uint8List? resultBytes;
      final filePaths = selectedFiles.map((f) => f.path!).toList();

      // --- Native processing ---
      if (selectedTool == 'Merge PDF') {
        initialCachePath = await mergePdfsNative(filePaths);
      } else if (selectedTool == 'Image to PDF') {
        initialCachePath = await imageToPdfNative(filePaths);
      } else if (selectedTool == 'Encrypt PDF') {
        final password = await _promptPassword(context, action: "Encrypt");
        if (password == null || password.isEmpty) {
          throw Exception("Encryption password not provided.");
        }
        initialCachePath = await encryptPdf(filePaths.first, password);
      } else if (selectedTool == 'Unlock PDF') {
        final password = await _promptPassword(context, action: "Unlock");

        if (password == null || password.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("🔑 Please enter a password to unlock the PDF.")),
          );
          return;
        }

        try {
          initialCachePath = await unlockPdf(filePaths.first, password);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("❌ Incorrect password. Please try again."),
            ),
          );
          return;
        }
      }

      if (initialCachePath == null) {
        throw Exception("Failed to create temporary PDF file.");
      }

      final tempFile = File(initialCachePath);
      if (await tempFile.exists()) {
        resultBytes = await tempFile.readAsBytes();
      } else {
        throw Exception("Temporary file not found at $initialCachePath");
      }

      ref.read(mergedPdfBytesProvider.notifier).state = resultBytes;

      // Dismiss loading dialog before save screen
      if (context.mounted) Navigator.pop(context);

      final bool? didSave = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SavePdfOverlay(
          pdfBytes: resultBytes!,
        ),
      );

      if (didSave != true) {
        if (await tempFile.exists()) {
          await tempFile.delete();
          print("Save cancelled. Temp file deleted: $initialCachePath");
        }
        return;
      }

      final outputPath = ref.read(savePathProvider);
      if (outputPath == null || outputPath.isEmpty) {
        throw Exception("Save path is missing after successful save.");
      }

      final recent = ref.read(recentFilesProvider);
      final updated = [outputPath, ...recent].toSet().toList();
      ref.read(recentFilesProvider.notifier).state = updated.take(4).toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProcessSuccessScreen(
            resultPath: outputPath,
          ),
        ),
      );
    } catch (e) {
      print("Error in _processFiles: ${e.toString()}");

      // Make sure to close the spinner in case of error
      if (context.mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred: ${e.toString()}")),
      );
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
          break;

        case 'Image to PDF':
          result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: true,
            withData: false,
          );
          break;

        case 'Encrypt PDF':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            allowMultiple: false,
            withData: false,
          );
          break;

        case 'Unlock PDF':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            allowMultiple: false,
            withData: false,
          );
          break;
      }

      // ✅ Only show loading dialog AFTER user has picked files
      if (result != null && result.files.isNotEmpty) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Dialog(
            backgroundColor: Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 20),
                  Flexible(
                    child: Text(
                      "Loading files...",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Short delay to make dialog visible
        await Future.delayed(const Duration(milliseconds: 150));

        // ✅ Add files to provider
        switch (selectedTool) {
          case 'Merge PDF':
            ref.read(mergePdfFilesProvider.notifier).addFiles(result.files);
            break;
          case 'Image to PDF':
            ref.read(imageToPdfFilesProvider.notifier).addFiles(result.files);
            break;
          case 'Encrypt PDF':
            ref.read(encryptPdfFilesProvider.notifier).addFiles(result.files);
            break;
          case 'Unlock PDF':
            ref.read(unlockPdfFilesProvider.notifier).addFiles(result.files);
            break;
        }
      }

    } catch (e, stackTrace) {
      debugPrint("Error during tool selection: $e");
      debugPrint("StackTrace: $stackTrace");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong while picking files.")),
      );
    } finally {
      // ✅ Always dismiss dialog if open
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }



  @override
  Widget build(BuildContext context) {

    final selectedTool = ref.watch(selectedToolProvider);

    // Map tool name to its respective provider

    // Use fallback to avoid crashes if tool not found
    final currentProvider = fileProviders[selectedTool] ?? mergePdfFilesProvider;

    final filesNotifier = ref.read(currentProvider.notifier);
    final selectedFiles = ref.watch(currentProvider);

    // final filesNotifier = ref.read(fileProviders[selectedTool]!.notifier);
    // final selectedFiles = ref.watch(fileProviders[selectedTool]!);

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
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
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
                            child: Row(
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
                                'assets/2.png',
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
