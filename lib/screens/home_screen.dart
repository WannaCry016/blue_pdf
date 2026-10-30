import 'dart:io';
import 'package:blue_pdf/main.dart';
import 'package:blue_pdf/components/split_view.dart';
import 'package:blue_pdf/services/update_service.dart';
import 'package:open_filex/open_filex.dart';
import '../components/camera.dart';
import '../components/dropdown.dart';
import '../components/pdf_password_dialog.dart';
import '../pdf/image_formats.dart';
import '../pdf/pdf_engine.dart';
import 'process_success_screen.dart';
import 'about_page.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../components/save_pdf.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/grid_view_overlay.dart';

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
    'Split PDF': splitPdfFilesProvider,
    'Reorder PDF': reorderPdfFilesProvider,
  };

  bool _busyDialogOpen = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showBusyDialog(String message) {
    if (_busyDialogOpen) return;
    _busyDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDarkMode = Theme.of(dialogContext).brightness == Brightness.dark;
        return PopScope(
          canPop: false,
          child: Dialog(
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
                      message,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? kDarkText : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideBusyDialog() {
    if (!_busyDialogOpen || !mounted) return;
    _busyDialogOpen = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<String?> _promptPassword({required String action}) async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$action PDF"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Password"),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(action),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  String _progressLabel(String tool, int count) => switch (tool) {
        'Merge PDF' => 'Merging $count PDFs...',
        'Image to PDF' => count == 1 ? 'Creating PDF...' : 'Creating PDF from $count images...',
        'Encrypt PDF' => 'Protecting PDF...',
        'Split PDF' => 'Splitting PDF...',
        'Reorder PDF' => 'Reordering pages...',
        _ => 'Processing PDF...',
      };

  Future<String> _imagesToPdf(List<SelectedFile> files) async {
    final result = await PdfEngine.imagesToPdf(
      files.map((f) => f.path).toList(),
      rotations: files.map((f) => f.rotation).toList(),
      fitToImage: ref.read(pageSizeProvider) == PageSize.fit,
    );
    if (result.skipped.isNotEmpty) {
      final names = result.skipped.map((i) => files[i].name).join(', ');
      _showMessage("Skipped images that couldn't be read: $names");
    }
    return result.path;
  }

  Future<void> _processFiles() async {
    final tool = ref.read(selectedToolProvider);
    final provider = fileProviders[tool];
    if (tool == null || provider == null) {
      _showMessage("Please select a tool and files first.");
      return;
    }
    final files = ref.read(provider);
    if (files.isEmpty || ref.read(isProcessingProvider)) return;

    // Ask for everything up front so the progress dialog is not interrupted.
    String? newPassword;
    List<int>? splitPages;
    if (tool == 'Encrypt PDF') {
      newPassword = await _promptPassword(action: "Encrypt");
      if (newPassword == null) return;
      if (newPassword.isEmpty) {
        _showMessage("Please enter a password to encrypt.");
        return;
      }
    } else if (tool == 'Split PDF') {
      final file = files.first;
      final PdfInfo info;
      try {
        info = await PdfEngine.inspect(file.path, password: file.password);
      } on PdfFailure catch (failure) {
        _showMessage(failure.message);
        return;
      }
      if (!mounted) return;
      splitPages = await SplitPdfDialog.show(context, file, info.pageCount);
      if (splitPages == null) return;
    }
    if (!mounted) return;

    ref.read(isProcessingProvider.notifier).state = true;
    _showBusyDialog(_progressLabel(tool, files.length));

    String? outputPath;
    try {
      outputPath = switch (tool) {
        'Merge PDF' => await PdfEngine.merge(
            files.map((f) => f.path).toList(),
            passwords: files.map((f) => f.password).toList(),
          ),
        'Image to PDF' => await _imagesToPdf(files),
        'Encrypt PDF' => await PdfEngine.encrypt(files.first.path, newPassword!),
        'Split PDF' => await PdfEngine.extractPages(
            files.first.path,
            splitPages!,
            password: files.first.password,
          ),
        'Reorder PDF' => await PdfEngine.extractPages(
            files.first.path,
            [for (final f in files) f.pageIndex!],
            password: files.first.password,
            rotations: [for (final f in files) f.rotation],
          ),
        _ => throw StateError('Unknown tool: $tool'),
      };
    } on PdfFailure catch (failure) {
      debugPrint('$tool failed: $failure');
      _hideBusyDialog();
      _showMessage(failure.message);
    } catch (e, stack) {
      debugPrint('$tool failed: $e\n$stack');
      _hideBusyDialog();
      _showMessage("Something went wrong. Please try again.");
    } finally {
      if (mounted) ref.read(isProcessingProvider.notifier).state = false;
    }

    if (outputPath == null || !mounted) return;
    _hideBusyDialog();

    final source = outputPath;
    final saved = await showModalBottomSheet<SavedPdf>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SavePdfOverlay(sourcePath: source),
    );
    if (saved == null) {
      File(source).delete().ignore();
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProcessSuccessScreen(saved: saved)),
    );
  }

  /// Opens each picked PDF once: unlocks protected files (or rejects them for
  /// tools that cannot use them) and drops files that cannot be read.
  Future<List<(SelectedFile, PdfInfo)>> _admitPdfs(
    List<SelectedFile> files, {
    bool rejectProtected = false,
  }) async {
    final admitted = <(SelectedFile, PdfInfo)>[];
    for (final file in files) {
      try {
        admitted.add((file, await PdfEngine.inspect(file.path)));
        continue;
      } on PdfFailure catch (failure) {
        if (failure.code != PdfErrorCode.passwordRequired) {
          _showMessage('"${file.name}": ${failure.message}');
          continue;
        }
      }

      if (rejectProtected) {
        _showMessage('"${file.name}" is already password-protected.');
        continue;
      }
      if (!mounted) break;

      PdfInfo? unlocked;
      final password = await showPdfPasswordDialog(
        context,
        fileName: file.name,
        verify: (password) async {
          try {
            unlocked = await PdfEngine.inspect(file.path, password: password);
            return true;
          } on PdfFailure {
            return false;
          }
        },
      );
      final info = unlocked;
      if (password != null && info != null) {
        admitted.add((file.copyWith(password: password), info));
      }
    }
    return admitted;
  }

  Future<void> _pickFiles() async {
    final tool = ref.read(selectedToolProvider);
    if (tool == null) return;

    final List<PlatformFile> picked;
    try {
      if (tool == 'Image to PDF') {
        picked = await FilePicker.pickFiles(type: FileType.image);
      } else if (tool == 'Merge PDF') {
        picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      } else {
        final single = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
        picked = single == null ? [] : [single];
      }
    } catch (e) {
      debugPrint('File picker failed: $e');
      _showMessage("Couldn't open the file picker.");
      return;
    }
    if (picked.isEmpty || !mounted) return;

    _showBusyDialog(tool == 'Image to PDF' ? 'Loading images...' : 'Loading files...');
    List<SelectedFile> files;
    try {
      files = await Future.wait(picked.map(SelectedFile.fromPicked));
      if (tool == 'Image to PDF') {
        final prepared = await Future.wait(files.map(ensureNativeImage));
        files = prepared.whereType<SelectedFile>().toList();
        final failed = prepared.length - files.length;
        if (failed > 0) {
          _showMessage(failed == 1
              ? "1 image couldn't be read and was skipped."
              : "$failed images couldn't be read and were skipped.");
        }
      }
    } catch (e) {
      debugPrint('Loading picked files failed: $e');
      _hideBusyDialog();
      _showMessage("Couldn't load the selected files.");
      return;
    }
    _hideBusyDialog();

    switch (tool) {
      case 'Image to PDF':
        ref.read(imageToPdfFilesProvider.notifier).addFiles(files);
      case 'Merge PDF':
        final admitted = await _admitPdfs(files);
        if (mounted) ref.read(mergePdfFilesProvider.notifier).addFiles([for (final a in admitted) a.$1]);
      case 'Encrypt PDF':
        final admitted = await _admitPdfs(files, rejectProtected: true);
        if (mounted && admitted.isNotEmpty) {
          ref.read(encryptPdfFilesProvider.notifier).setFiles([admitted.first.$1]);
        }
      case 'Split PDF':
        final admitted = await _admitPdfs(files);
        if (mounted && admitted.isNotEmpty) {
          ref.read(splitPdfFilesProvider.notifier).setFiles([admitted.first.$1]);
        }
      case 'Reorder PDF':
        final admitted = await _admitPdfs(files);
        if (mounted && admitted.isNotEmpty) {
          final (file, info) = admitted.first;
          ref.read(reorderPdfFilesProvider.notifier).setFiles([
            for (var i = 0; i < info.pageCount; i++)
              SelectedFile(name: 'Page ${i + 1}', path: file.path, password: file.password, pageIndex: i),
          ]);
        }
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

    final isProcessing = ref.watch(isProcessingProvider);
    
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
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
        builder: (context, constraints) {
          final isTab = isTablet(context);
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = isDark ? kDarkText : Colors.black87;
          final secondaryTextColor = isDark ? kDarkSecondaryText : Colors.grey.shade600;
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
                        _pickFiles();
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
                              color: isDark ? kDarkTeal.withValues(alpha: 0.25) : Colors.blue.withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.1),
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

                    if (selectedFiles.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: screenHeight * (isTab ? 0.03 : 0.02)),
                        child: Text(
                          "Upload a file to begin. Supported: PDF, JPG, PNG, HEIC, WebP.",
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
                                    onReorderItem: (oldIndex, newIndex) {
                                      filesNotifier.move(oldIndex, newIndex);
                                    },
                                    padding: EdgeInsets.zero,
                                    buildDefaultDragHandles: true,
                                    itemBuilder: (context, index) {
                                      final file = selectedFiles[index];

                                      IconData iconData;
                                      Color iconColor;

                                      if (file.pageIndex != null || file.extension == 'pdf') {
                                        iconData = Icons.picture_as_pdf_rounded;
                                        iconColor = isDark ? kDarkAccent : Colors.blueAccent;
                                      } else {
                                        iconData = Icons.image_outlined;
                                        iconColor = isDark ? Colors.tealAccent : Colors.teal;
                                      }

                                      return ListTile(
                                        key: ValueKey(file.id),
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
                                        onTap: () => OpenFilex.open(file.path),
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
                                color: (isDark ? kDarkAccent : Colors.blueAccent).withValues(alpha: 0.3),
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
                                            color: textColor.withValues(alpha: 0.55),
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
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: GridViewOverlay(
                        files: selectedFiles,
                        onRemoveFile: (index) => filesNotifier.removeFileAt(index),
                        onReorder: (oldIndex, newIndex) => filesNotifier.move(oldIndex, newIndex),
                        onRotate: (index) => filesNotifier.rotateClockwise(index),
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
      ),
    );
  }
}
