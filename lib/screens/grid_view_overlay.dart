import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';
import '../state_providers.dart';

// Dark color palette
const Color kDarkBg = Color(0xFF101A30);
const Color kDarkCard = Color(0xFF1A2236);
const Color kDarkBorder = Color(0xFF232A3B);
const Color kDarkPrimary = Color(0xFF2979FF);
const Color kDarkAccent = Color(0xFF536DFE);
const Color kDarkTeal = Color(0xFF00B8D4);
const Color kDarkText = Colors.white;
const Color kDarkSecondaryText = Color(0xFFB0B8C1);

class GridViewOverlay extends ConsumerStatefulWidget {
  final List<PlatformFile> files;
  final Function(int) onRemoveFile;
  final Function(int, int) onReorder;
  final bool isDark;
  final Color textColor;
  final Color cardColor;
  final Color borderColor;
  final VoidCallback? onClose;

  const GridViewOverlay({
    super.key,
    required this.files,
    required this.onRemoveFile,
    required this.onReorder,
    required this.isDark,
    required this.textColor,
    required this.cardColor,
    required this.borderColor,
    this.onClose,
  });

  @override
  ConsumerState<GridViewOverlay> createState() => _GridViewOverlayState();
}

class _GridViewOverlayState extends ConsumerState<GridViewOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Rotation state for images
  final Map<String, double> _rotationAngles = {};
  
  // Drag and drop state
  int? _draggedIndex;
  int? _dragTargetIndex;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closeOverlay() async {
    // First set the view mode to list immediately for responsive UI
    ref.read(viewModeProvider.notifier).state = ViewMode.list;
    
    // Then animate the overlay closing
    await _animationController.reverse();
    
    if (mounted) {
      // Call the callback to notify parent
      widget.onClose?.call();
    }
  }

  void _rotateImage(String filePath) {
    setState(() {
      final currentAngle = _rotationAngles[filePath] ?? 0.0;
      _rotationAngles[filePath] = (currentAngle + 90) % 360;
    });
  }

  void _onDragStarted(int index) {
    setState(() {
      _draggedIndex = index;
      _isDragging = true;
    });
  }

  void _onDragEnd() {
    setState(() {
      _draggedIndex = null;
      _dragTargetIndex = null;
      _isDragging = false;
    });
  }

  void _onDragAccepted(int newIndex) {
    final oldIndex = _draggedIndex;
    if (oldIndex != null && oldIndex != newIndex) {
      widget.onReorder(oldIndex, newIndex);
    }
    setState(() {
      _draggedIndex = null;
      _dragTargetIndex = null;
      _isDragging = false;
    });
  }

  void _onDragTargetUpdate(int? targetIndex) {
    setState(() {
      _dragTargetIndex = targetIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.7,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: widget.isDark ? Colors.black38 : Colors.black26,
                blurRadius: 20,
                offset: const Offset(0, 10),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDark ? kDarkBorder : Colors.grey.shade100,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          color: widget.isDark ? kDarkAccent : Colors.blueAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Files Grid View",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: widget.textColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: widget.isDark ? kDarkAccent : Colors.blueAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "${widget.files.length}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _closeOverlay,
                      icon: Icon(
                        Icons.close,
                        color: widget.textColor.withOpacity(0.7),
                        size: 24,
                      ),
                      tooltip: "Close Grid View",
                    ),
                  ],
                ),
              ),
              
              // Grid Content
              Expanded(
                child: widget.files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open_outlined,
                              size: 64,
                              color: widget.textColor.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No files selected",
                              style: TextStyle(
                                fontSize: 16,
                                color: widget.textColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: widget.files.length,
                          itemBuilder: (context, index) {
                            final file = widget.files[index];
                            final isPdf = file.extension?.toLowerCase() == 'pdf';
                            
                            return _buildDraggableFileCard(file, index, isPdf);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableFileCard(PlatformFile file, int index, bool isPdf) {
    final isDragging = _draggedIndex == index;
    final isDragTarget = _dragTargetIndex == index && _draggedIndex != null && _draggedIndex != index;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data != null && data != index) {
          _onDragTargetUpdate(index);
          return true;
        }
        return false;
      },
      onAcceptWithDetails: (details) => _onDragAccepted(index),
      onLeave: (data) => _onDragTargetUpdate(null),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<int>(
          data: index,
          delay: const Duration(milliseconds: 300), // Hold for 300ms to start drag
          onDragStarted: () => _onDragStarted(index),
          onDragEnd: (details) => _onDragEnd(),
          hapticFeedbackOnStart: true,
          feedback: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: widget.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.borderColor),
              ),
              child: _buildFileCard(file, index, isPdf, isDragging: true),
            ),
          ),
          childWhenDragging: Container(
            decoration: BoxDecoration(
              color: widget.isDark ? kDarkCard.withOpacity(0.3) : Colors.grey.shade50.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.borderColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(Icons.drag_handle, color: Colors.grey),
            ),
          ),
          child: _buildFileCard(file, index, isPdf, isDragging: isDragging, isDragTarget: isDragTarget),
        );
      },
    );
  }

  Widget _buildFileCard(PlatformFile file, int index, bool isPdf, {bool isDragging = false, bool isDragTarget = false}) {
    return Container(
      key: ValueKey(file.path),
      decoration: BoxDecoration(
        color: widget.isDark ? kDarkCard : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDragTarget 
            ? (widget.isDark ? kDarkAccent : Colors.blueAccent)
            : widget.borderColor.withOpacity(0.5),
          width: isDragTarget ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDark ? Colors.black12 : Colors.black.withOpacity(0.08),
            blurRadius: isDragging ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (_isDragging) return; // Prevent tap during drag
                final filePath = file.path!;
                try {
                  await OpenFilex.open(filePath);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Could not open file")),
                  );
                }
              },
              child: Stack(
                children: [
                  // File preview
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: isPdf
                        ? _buildPdfPreview(file)
                        : _buildImagePreview(file),
                  ),
                  
                  // Drag handle indicator - show for both images and PDFs
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Action bar
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: widget.isDark ? kDarkBorder : Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!isPdf) ...[
                  // Rotate button for images
                  GestureDetector(
                    onTap: () => _rotateImage(file.path!),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.rotate_right,
                        color: widget.textColor.withOpacity(0.7),
                        size: 18,
                      ),
                    ),
                  ),
                ] else ...[
                  // PDF indicator
                  Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.picture_as_pdf,
                      color: widget.isDark ? kDarkAccent : Colors.blueAccent,
                      size: 18,
                    ),
                  ),
                ],
                
                // Cross button
                GestureDetector(
                  onTap: () => widget.onRemoveFile(index),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.close,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPreview(PlatformFile file) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: widget.isDark ? kDarkCard : Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_rounded,
            size: 32,
            color: widget.isDark ? kDarkAccent : Colors.blueAccent,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              file.name,
              style: TextStyle(
                fontSize: 10,
                color: widget.textColor,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(PlatformFile file) {
    return FutureBuilder<File?>(
      future: Future.value(File(file.path!)),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.existsSync()) {
          final rotationAngle = _rotationAngles[file.path!] ?? 0.0;
          
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: widget.isDark ? kDarkCard : Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Transform.rotate(
                angle: rotationAngle * 3.14159 / 180, // Convert degrees to radians
                child: Image.file(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildImageErrorWidget(file.name);
                  },
                ),
              ),
            ),
          );
        } else {
          return _buildImageErrorWidget(file.name);
        }
      },
    );
  }

  Widget _buildImageErrorWidget(String fileName) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: widget.isDark ? kDarkCard : Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: widget.textColor.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              fileName,
              style: TextStyle(
                fontSize: 12,
                color: widget.textColor,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
} 