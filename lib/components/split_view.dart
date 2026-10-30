import 'dart:async';

import 'package:flutter/material.dart';

import '../pdf/page_ranges.dart';
import '../state_providers.dart';
import 'pdf_page_thumbnail.dart';

/// Lets the user choose which pages to keep. Returns 0-based page indices.
class SplitPdfDialog extends StatefulWidget {
  const SplitPdfDialog({super.key, required this.file, required this.pageCount});

  final SelectedFile file;
  final int pageCount;

  static Future<List<int>?> show(BuildContext context, SelectedFile file, int pageCount) {
    return showDialog<List<int>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SplitPdfDialog(file: file, pageCount: pageCount),
    );
  }

  @override
  State<SplitPdfDialog> createState() => _SplitPdfDialogState();
}

class _SplitPdfDialogState extends State<SplitPdfDialog> {
  late final TextEditingController _controller;
  Timer? _debounce;
  List<int> _pages = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.pageCount == 1 ? '1' : '1-${widget.pageCount}',
    );
    _parse();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _parse() {
    try {
      _pages = parsePageRanges(_controller.text, widget.pageCount);
      _error = null;
    } on FormatException catch (e) {
      _error = e.message;
    }
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(_parse);
    });
  }

  void _submit() {
    _debounce?.cancel();
    setState(_parse);
    if (_error == null && _pages.isNotEmpty) Navigator.pop(context, _pages);
  }

  Widget _buildPreview({
    required String label,
    required int? page,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color accent,
    required double height,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: page == null
                  ? Center(
                      child: Icon(Icons.picture_as_pdf_outlined, size: height * 0.2, color: accent.withValues(alpha: 0.6)),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: PdfPageThumbnail(
                            path: widget.file.path,
                            page: page,
                            password: widget.file.password,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              '${page + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isSmallScreen = screenSize.width < 600 || screenSize.height < 700;
    final dialogWidth = isSmallScreen ? screenSize.width * 0.95 : 600.0;
    final previewHeight = isSmallScreen ? 180.0 : 240.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A2236) : Colors.white;
    final borderColor = isDark ? const Color(0xFF232A3B) : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? const Color(0xFFB0B8C1) : Colors.grey;
    final accent = isDark ? const Color(0xFF2979FF) : const Color(0xFF1976D2);
    final gradientColors = isDark
        ? [const Color(0xFF2979FF), const Color(0xFF536DFE), const Color(0xFF00B8D4)]
        : [const Color(0xFF0D47A1), const Color(0xFF1976D2)];

    final selectionText = _error ??
        '${_pages.length} of ${widget.pageCount} ${widget.pageCount == 1 ? 'page' : 'pages'} selected';
    final hasSelection = _error == null && _pages.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 10 : 20, vertical: isSmallScreen ? 20 : 40),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: screenSize.height * 0.9),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.content_cut, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  const Text('Split PDF', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPreview(
                          label: 'First page',
                          page: hasSelection ? _pages.first : null,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          textColor: textColor,
                          accent: accent,
                          height: previewHeight,
                        ),
                        const SizedBox(width: 16),
                        _buildPreview(
                          label: 'Last page',
                          page: hasSelection ? _pages.last : null,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          textColor: textColor,
                          accent: accent,
                          height: previewHeight,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Pages to keep', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.visiblePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: _onChanged,
                      onSubmitted: (_) => _submit(),
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'e.g. 1-3, 7, 9-12',
                        hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 14),
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accent, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        suffixText: '/ ${widget.pageCount}',
                        suffixStyle: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectionText,
                      style: TextStyle(
                        color: _error == null ? secondaryTextColor : Colors.red.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1419) : Colors.grey[50],
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: secondaryTextColor, fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 8),
                  Opacity(
                    opacity: hasSelection ? 1 : 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradientColors),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: hasSelection ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Split PDF',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
