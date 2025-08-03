
import 'dart:io';
import 'dart:ui';
import 'package:blue_pdf/main.dart';
import 'package:blue_pdf/screens/split_view.dart';
import 'package:blue_pdf/services/pdf_encryptor.dart';
import 'package:blue_pdf/services/update_service.dart';
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
import 'package:blue_pdf/services/split_pdf.dart';
import 'package:blue_pdf/services/reorder_pdf.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'grid_view_overlay.dart';

// Update dark color palette for more vibrant, attractive look
const Color kDarkBg = Color(0xFF101A30);         // Deep navy
const Color kDarkCard = Color(0xFF1A2236);       // Soft card
const Color kDarkBorder = Color(0xFF232A3B);
const Color kDarkPrimary = Color(0xFF2979FF);    // Vibrant blue
const Color kDarkAccent = Color(0xFF536DFE);     // Electric indigo
const Color kDarkTeal = Color(0xFF00B8D4);       // Teal accent
const Color kDarkText = Colors.white;
const Color kDarkSecondaryText = Color(0xFFB0B8C1);


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {

  // Static variable to track if we've checked for updates
  static bool _hasCheckedForUpdate = false;

  final fileProviders = {
      'Merge PDF': mergePdfFilesProvider,
      'Image to PDF': imageToPdfFilesProvider,
      'Encrypt PDF': encryptPdfFilesProvider,
      'Split PDF': mergePdfFilesProvider, // Use mergePdfFilesProvider for single PDF selection
      'Reorder PDF': reorderPdfFilesProvider,
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
      builder: (_) => Builder(
        builder: (dialogContext) {
          final isDarkMode = Theme.of(dialogContext).brightness == Brightness.dark;
          return Dialog(
            backgroundColor: isDarkMode ? kDarkCard : Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDarkMode ? kDarkAccent : Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Flexible(
                    child: Text(
                      "Processing PDF...", 
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? kDarkText : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
        initialCachePath = await mergePdfNative(filePaths);
      } else if (selectedTool == 'Image to PDF') {
        final pageSize = ref.read(pageSizeProvider);
        final pageMode = pageSize == PageSize.a4 ? "A4" : "FIT";
        initialCachePath = await imageToPdfNative(filePaths, pageMode);
      } else if (selectedTool == 'Encrypt PDF') {
        final password = await _promptPassword(context, action: "Encrypt");
        if (password == null || password.isEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("⚠️ Please enter a password to encrypt."),
                duration: Duration(seconds: 1), // 👈 this goes inside
              ),
            );
            // Dismiss loading dialog before save screen
            Navigator.pop(context);
          }
          return; // ✅ this exits the try block and the function
        }
        initialCachePath = await encryptPdfNative(filePaths.first, password); 
      } else if (selectedTool == 'Split PDF') {
        // Prompt for page range
        final range = await SplitPdfDialog.show(context, filePaths.first);
        if (range == null) {
          Navigator.pop(context); // Dismiss loading dialog
          ref.read(isProcessingProvider.notifier).state = false;
          return;
        }
        final start = range['start']!;
        final end = range['end']!;
        final pages = [for (int i = start; i <= end; i++) i];
        final outputPaths = await splitPdfNative(filePaths.first, pages);
        // For consistency, set initialCachePath to the first output (or handle as needed)
        initialCachePath = outputPaths;
      } else if (selectedTool == 'Reorder PDF') {
        // Use imageToPdfNative to convert reordered images back to PDF
        final pageMode = "FIT";
        initialCachePath = await imageToPdfNative(filePaths, pageMode);
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

        case 'Split PDF':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            allowMultiple: false,
            withData: false,
          );
          break;
          
        case 'Reorder PDF':
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
          builder: (_) => Builder(
            builder: (dialogContext) {
              final isDarkMode = Theme.of(dialogContext).brightness == Brightness.dark;
              return Dialog(
                backgroundColor: isDarkMode ? kDarkCard : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDarkMode ? kDarkAccent : Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Flexible(
                        child: Text(
                          "Loading files...",
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode ? kDarkText : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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
          case 'Split PDF':
            ref.read(mergePdfFilesProvider.notifier).addFiles(result.files);
            break;
          case 'Reorder PDF':
            if (result.files.isNotEmpty) {
              try {
                // Convert PDF to images and add to provider
                final imagePaths = await reorderPdfNative(result.files.first.path!);
                final imageFiles = imagePaths.map((path) => PlatformFile(
                  name: path.split('/').last,
                  path: path,
                  size: 0,
                )).toList();
                ref.read(reorderPdfFilesProvider.notifier).addFiles(imageFiles);
              } catch (e) {
                debugPrint("Reorder PDF Error: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Failed to process PDF for reordering: ${e.toString()}"),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
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

  // Responsive helper: returns true if device is a tablet (width > 600dp)
  bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.shortestSide;
    return width >= 600;
  }

  // Responsive size helpers
  T responsive<T>(BuildContext context, T phone, T tablet) => isTablet(context) ? tablet : phone;


  @override
  Widget build(BuildContext context) {

    final selectedTool = ref.watch(selectedToolProvider);
    final viewMode = ref.watch(viewModeProvider);

    // Map tool name to its respective provider

    // Use fallback to avoid crashes if tool not found
    final currentProvider = fileProviders[selectedTool] ?? mergePdfFilesProvider;

    final filesNotifier = ref.read(currentProvider.notifier);
    final selectedFiles = ref.watch(currentProvider);

    // final filesNotifier = ref.read(fileProviders[selectedTool]!.notifier);
    // final selectedFiles = ref.watch(fileProviders[selectedTool]!);

    final isLoading = ref.watch(isFileLoadingProvider);
    var isProcessing = ref.watch(isProcessingProvider);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? kDarkBg : const Color(0xFFECEFF1);
    final gradientColors = isDark
        ? [kDarkPrimary, kDarkAccent, kDarkTeal]
        : [Color(0xFF0D47A1), Color(0xFF1976D2)];

    // Check for updates only once when the widget builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasCheckedForUpdate) {
        _hasCheckedForUpdate = true;
        UpdateService.checkForUpdate(context);
      }
    });

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTab = isTablet(context);
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isDark ? kDarkText : Colors.black87;
          final secondaryTextColor = isDark ? kDarkSecondaryText : Colors.grey.shade600;
          final bgColor = isDark ? kDarkBg : const Color(0xFFECEFF1);
          final cardColor = isDark ? kDarkCard : Colors.white;
          final borderColor = isDark ? kDarkBorder : Colors.grey.shade300;
          final gradientColors = isDark
              ? [kDarkPrimary, kDarkAccent, kDarkTeal]
              : [Color(0xFF0D47A1), Color(0xFF1976D2)];

          // Calculate dynamic sizes (responsive for tablet)
          final double screenHeight = constraints.maxHeight;
          final double screenWidth = constraints.maxWidth;
          final double boxImageSize = isTab ? screenWidth * 0.22 : screenWidth * 0.35;
          final double boxPadding = isTab ? screenHeight * 0.06 : screenHeight * 0.04;
          final double boxMinHeight = isTab ? screenHeight * 0.32 : screenHeight * 0.22;
          final double boxMaxHeight = isTab ? screenHeight * 0.45 : screenHeight * 0.32;
          final double mainFont = isTab ? 22 : 16;
          final double subFont = isTab ? 18 : 14;
          final double buttonFont = isTab ? 18 : 15.5;
          final double iconSize = isTab ? 36 : 22;
          final double uploadIconSize = isTab ? 38 : 26;
          final double uploadFont = isTab ? 28 : 22;
          final double listTileFont = isTab ? 20 : 14.5;
          final double listTileIcon = isTab ? 30 : 22;
          final double closeIcon = isTab ? 28 : 20;
          final double gridThumb = isTab ? 120 : 70;
          final double cameraButtonSize = isTab ? 120 : 96;

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * (isTab ? 0.12 : 0.05),
                  vertical: screenHeight * (isTab ? 0.07 : 0.04),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (selectedTool == null) {
                          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Please select a tool before choosing a file",
                                      style: TextStyle(fontWeight: FontWeight.w500, color: isDarkMode ? Colors.white : Colors.black,),
                                    ),
                                  ),
                                ],
                              ),
                              duration: const Duration(seconds: 1),
                              backgroundColor: isDarkMode ? kDarkCard : Colors.white,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                          return;
                        }
                        _onToolSelect(); 
                      },
                      child: Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(right: screenWidth * 0.02),
                        padding: EdgeInsets.symmetric(vertical: screenHeight * (isTab ? 0.05 : 0.032)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? kDarkTeal.withOpacity(0.25) : Colors.blue.withOpacity(0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withOpacity(isDark ? 0.08 : 0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file_rounded, color: Colors.white, size: uploadIconSize),
                            SizedBox(width: 10),
                            Text(
                              "Select File",
                              style: TextStyle(
                                fontSize: uploadFont,
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
                        padding: EdgeInsets.only(top: screenHeight * (isTab ? 0.05 : 0.03)),
                        child: Column(
                          children: [
                            Text(
                              "Selected Files",
                              style: TextStyle(
                                fontSize: mainFont,
                                fontWeight: FontWeight.w600,
                                color: isDark ? kDarkSecondaryText : Colors.grey.shade700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(height: screenHeight * (isTab ? 0.03 : 0.018)),
                            SizedBox(
                              width: isTab ? 36 : 22,
                              height: isTab ? 36 : 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(isDark ? kDarkAccent : Color(0xFF1976D2)),
                              ),
                            ),
                          ],
                        ),
                      )

                    else if (selectedFiles.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: screenHeight * (isTab ? 0.03 : 0.02)),
                        child: Text(
                          "Upload a file to begin. Supported: PDF, JPG, PNG.",
                          style: TextStyle(
                            fontSize: subFont,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )

                    else
                      Padding(
                        padding: EdgeInsets.only(top: screenHeight * (isTab ? 0.04 : 0.03)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Selected Files",
                                  style: TextStyle(fontSize: mainFont, fontWeight: FontWeight.w600),
                                ),
                                if (selectedFiles.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Toggle only for Image to PDF
                                      if (selectedTool == 'Image to PDF') ...[
                                        SizedBox(width: isTab ? 12 : 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: cardColor,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: borderColor, width: 1),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: () => ref.read(pageSizeProvider.notifier).state = PageSize.a4,
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(horizontal: isTab ? 18 : 12, vertical: isTab ? 10 : 6),
                                                  decoration: BoxDecoration(
                                                    color: ref.watch(pageSizeProvider) == PageSize.a4 
                                                      ? (isDark ? kDarkAccent : Colors.blueAccent)
                                                      : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(18),
                                                  ),
                                                  child: Text(
                                                    "A4",
                                                    style: TextStyle(
                                                      fontSize: isTab ? 16 : 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: ref.watch(pageSizeProvider) == PageSize.a4 
                                                        ? Colors.white 
                                                        : textColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => ref.read(pageSizeProvider.notifier).state = PageSize.fit,
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(horizontal: isTab ? 18 : 12, vertical: isTab ? 10 : 6),
                                                  decoration: BoxDecoration(
                                                    color: ref.watch(pageSizeProvider) == PageSize.fit 
                                                      ? (isDark ? kDarkAccent : Colors.blueAccent)
                                                      : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(18),
                                                  ),
                                                  child: Text(
                                                    "Fit",
                                                    style: TextStyle(
                                                      fontSize: isTab ? 16 : 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: ref.watch(pageSizeProvider) == PageSize.fit 
                                                        ? Colors.white 
                                                        : textColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      const SizedBox(width: 12),
                                      // View Mode Toggle
                                      Container(
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: borderColor, width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () => ref.read(viewModeProvider.notifier).state = ViewMode.list,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: isTab ? 18 : 12, vertical: isTab ? 10 : 6),
                                                decoration: BoxDecoration(
                                                  color: viewMode == ViewMode.list 
                                                    ? (isDark ? kDarkAccent : Colors.blueAccent)
                                                    : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(18),
                                                ),
                                                child: Text(
                                                  "List",
                                                  style: TextStyle(
                                                    fontSize: isTab ? 16 : 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: viewMode == ViewMode.list 
                                                      ? Colors.white 
                                                      : textColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => ref.read(viewModeProvider.notifier).state = ViewMode.grid,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: isTab ? 18 : 12, vertical: isTab ? 10 : 6),
                                                decoration: BoxDecoration(
                                                  color: viewMode == ViewMode.grid 
                                                    ? (isDark ? kDarkAccent : Colors.blueAccent)
                                                    : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(18),
                                                ),
                                                child: Text(
                                                  "Grid",
                                                  style: TextStyle(
                                                    fontSize: isTab ? 16 : 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: viewMode == ViewMode.grid 
                                                      ? Colors.white 
                                                      : textColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    
                                    ],
                                  ),
                              ],
                            ),
                            SizedBox(height: isTab ? 10 : 5),
                            if (viewMode == ViewMode.list)
                              Container(
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1.2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                constraints: BoxConstraints(
                                  maxHeight: screenHeight * (isTab ? 0.45 : 0.28),
                                ),
                                child: Scrollbar(
                                  thumbVisibility: true,
                                  radius: const Radius.circular(8),
                                  thickness: isTab ? 6 : 3,
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
                                        iconColor = isDark ? kDarkAccent : Colors.blueAccent;
                                      } else {
                                        iconData = Icons.image_outlined;
                                        iconColor = isDark ? Colors.tealAccent : Colors.teal;
                                      }

                                      return ListTile(
                                        key: ValueKey(file.path),
                                        dense: !isTab,
                                        visualDensity: isTab ? VisualDensity(vertical: 0) : const VisualDensity(vertical: -4),
                                        contentPadding: EdgeInsets.symmetric(horizontal: isTab ? 24 : 12),
                                        leading: Icon(iconData, color: iconColor, size: listTileIcon),
                                        title: Text(
                                          file.name,
                                          style: TextStyle(fontSize: listTileFont, color: textColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: GestureDetector(
                                          onTap: () {
                                            filesNotifier.removeFileAt(index);
                                          },
                                          child: Icon(Icons.close_rounded, color: Colors.redAccent, size: closeIcon),
                                        ),
                                        onTap: () async {
                                          final filePath = file.path!;
                                          ref.read(selectedFilePathProvider.notifier).state = filePath;

                                          if (file.extension == 'pdf') {
                                            await OpenFilex.open(filePath);
                                          } else if ([
                                            'jpg', 'jpeg', 'png', 'gif'
                                          ].contains(file.extension!.toLowerCase())) {
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
                          ],
                        ),
                      ),

                    SizedBox(height: screenHeight * (isTab ? 0.025 : 0.012)),
                    if (selectedFiles.isNotEmpty)
                      Align(
                        alignment: Alignment.center,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: isProcessing ? (isTab ? 220 : 160) : (isTab ? 180 : 140),
                          height: isTab ? 60 : 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradientColors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? kDarkAccent : Colors.blueAccent).withOpacity(0.3),
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
                                  children: [
                                    Icon(Icons.play_arrow_rounded, size: isTab ? 30 : 22, color: Colors.white),
                                    SizedBox(width: isTab ? 14 : 8),
                                    Text(
                                      "Process",
                                      style: TextStyle(
                                        fontSize: buttonFont,
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

                    SizedBox(height: screenHeight * (isTab ? 0.04 : 0.025)),

                    CustomDropdown(
                      selectedTool: selectedTool,
                      onChanged: (val) {
                        ref.read(selectedToolProvider.notifier).state = val;
                      },
                      isDark: isDark,
                      textColor: textColor,
                      fontSize: isTab ? 20 : 16,
                      iconSize: isTab ? 32 : 22,
                      padding: EdgeInsets.symmetric(horizontal: isTab ? 24 : 12, vertical: isTab ? 16 : 10),
                    ),

                    SizedBox(height: screenHeight * (isTab ? 0.07 : 0.045)),
                    // Responsive box and camera area
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: selectedFiles.isEmpty
                            ? Container(
                                margin: EdgeInsets.symmetric(horizontal: screenWidth * (isTab ? 0.08 : 0.04)),
                                padding: EdgeInsets.all(boxPadding),
                                constraints: BoxConstraints(
                                  minHeight: isTab ? screenHeight * 0.35 : boxMinHeight,
                                  maxHeight: isTab ? screenHeight * 0.65 : boxMaxHeight * 1.5,
                                  minWidth: screenWidth * (isTab ? 0.7 : 0.6),
                                  maxWidth: screenWidth * (isTab ? 0.98 : 0.95),
                                ),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: borderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark ? Colors.black26 : Colors.black12,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      flex: 2,
                                      child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: Image.asset(
                                          'assets/2.png',
                                          height: boxImageSize,
                                          width: boxImageSize,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: screenHeight * (isTab ? 0.018 : 0.012)),
                                    Flexible(
                                      flex: 1,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: isTab ? 32 : 12),
                                        child: Text(
                                          "Start by choosing a tool or uploading a file.",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: subFont,
                                            fontWeight: FontWeight.w400,
                                            color: textColor.withOpacity(0.55),
                                            letterSpacing: 0.2,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: screenHeight * (isTab ? 0.014 : 0.01)),
                                  ],
                                ),
                              )
                            : SizedBox(height: isTab ? 20 : 10),
                      ),
                    ),

                    SizedBox(height: screenHeight * (isTab ? 0.018 : 0.01)),

                    Padding(
                      padding: EdgeInsets.only(bottom: screenHeight * (isTab ? 0.05 : 0.03)),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: cameraButtonSize,
                          height: cameraButtonSize,
                          child: CameraButton(
                            iconSize: isTab ? 56 : 40,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Grid View Overlay
              if (viewMode == ViewMode.grid && selectedFiles.isNotEmpty)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: GridViewOverlay(
                        files: selectedFiles,
                        onRemoveFile: (index) => filesNotifier.removeFileAt(index),
                        onReorder: (oldIndex, newIndex) => filesNotifier.reorder(oldIndex, newIndex),
                        isDark: isDark,
                        textColor: textColor,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        onClose: () {
                          ref.read(viewModeProvider.notifier).state = ViewMode.list;
                        },
                        thumbSize: gridThumb,
                        fontSize: listTileFont,
                        iconSize: listTileIcon,
                        closeIconSize: closeIcon,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
