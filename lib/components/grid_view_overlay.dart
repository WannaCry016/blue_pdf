import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import '../state_providers.dart';
import 'pdf_page_thumbnail.dart';

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
  final List<SelectedFile> files;
  final Function(int) onRemoveFile;
  final Function(int, int) onReorder;
  final ValueChanged<int> onRotate;
  final bool isDark;
  final Color textColor;
  final Color cardColor;
  final Color borderColor;
  final VoidCallback? onClose;
  final double thumbSize;
  final double fontSize;
  final double iconSize;
  final double closeIconSize;

  const GridViewOverlay({
    super.key,
    required this.files,
    required this.onRemoveFile,
    required this.onReorder,
    required this.onRotate,
    required this.isDark,
    required this.textColor,
    required this.cardColor,
    required this.borderColor,
    this.onClose,
    this.thumbSize = 70,
    this.fontSize = 14.5,
    this.iconSize = 22,
    this.closeIconSize = 20,
  });

  @override
  ConsumerState<GridViewOverlay> createState() => _GridViewOverlayState();
}

class _GridViewOverlayState extends ConsumerState<GridViewOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
                          size: widget.iconSize,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Files Grid View",
                          style: TextStyle(
                            fontSize: widget.fontSize + 3.5,
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
                            style: TextStyle(
                              fontSize:  widget.fontSize - 2.5,
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
                        color: widget.textColor.withValues(alpha: 0.7),
                        size: widget.closeIconSize,
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
                              size: widget.iconSize - 10,
                              color: widget.textColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No files selected",
                              style: TextStyle(
                                fontSize: widget.fontSize - 2.5,
                                color: widget.textColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: widget.thumbSize > 100 ? 4 : 3,
                            crossAxisSpacing: widget.thumbSize / 5,
                            mainAxisSpacing: widget.thumbSize / 5,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: widget.files.length,
                          itemBuilder: (context, index) {
                            final file = widget.files[index];
                            final isPdf = file.pageIndex != null || file.extension == 'pdf';

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

  Widget _buildDraggableFileCard(SelectedFile file, int index, bool isPdf) {
    final isDragging = _draggedIndex == index;
    final isDragTarget = _dragTargetIndex == index && _draggedIndex != null && _draggedIndex != index;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data != index) {
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
              width: widget.thumbSize * 1.7,
              height: widget.thumbSize * 2.2,
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
              color: widget.isDark ? kDarkCard.withValues(alpha: 0.3) : Colors.grey.shade50.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.borderColor.withValues(alpha: 0.3),
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

  Widget _buildFileCard(SelectedFile file, int index, bool isPdf, {bool isDragging = false, bool isDragTarget = false}) {
    final canRotate = !isPdf || file.pageIndex != null;
    return Container(
      key: ValueKey(file.id),
      decoration: BoxDecoration(
        color: widget.isDark ? kDarkCard : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDragTarget 
            ? (widget.isDark ? kDarkAccent : Colors.blueAccent)
            : widget.borderColor.withValues(alpha: 0.5),
          width: isDragTarget ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isDark ? Colors.black12 : Colors.black.withValues(alpha: 0.08),
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
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await OpenFilex.open(file.path);
                } catch (e) {
                  messenger.showSnackBar(
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
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.drag_handle,
                        color: Colors.white,
                        size: widget.iconSize - 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Action bar
          Container(
            height: widget.thumbSize * 0.55,
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
                if (canRotate) ...[
                  GestureDetector(
                    onTap: () => widget.onRotate(index),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.rotate_right,
                        color: widget.textColor.withValues(alpha: 0.7),
                        size: widget.iconSize - 4,
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
                      size: widget.iconSize - 4,
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
                      size: widget.closeIconSize,
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

  Widget _buildPdfPreview(SelectedFile file) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: widget.isDark ? kDarkCard : Colors.grey.shade100,
      padding: const EdgeInsets.all(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PdfPageThumbnail(
            path: file.path,
            page: file.pageIndex ?? 0,
            password: file.password,
            rotation: file.rotation,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                file.name,
                style: TextStyle(fontSize: widget.fontSize - 4.5, color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(SelectedFile file) {
    final cacheWidth = (widget.thumbSize * 2 * MediaQuery.devicePixelRatioOf(context)).round();
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: widget.isDark ? kDarkCard : Colors.grey.shade100,
      child: RotatedBox(
        quarterTurns: file.rotation ~/ 90,
        child: Image.file(
          File(file.path),
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildImageErrorWidget(file.name),
        ),
      ),
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
            size: widget.iconSize + 18,
            color: widget.textColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              fileName,
              style: TextStyle(
                fontSize: widget.fontSize - 2.5,
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