import 'dart:io';

import 'package:flutter/material.dart';

import '../pdf/pdf_engine.dart';

/// Renders one PDF page through the native engine. Results are memoised in
/// memory and cached on disk by the platform side, so scrolling back is instant.
class PdfPageThumbnail extends StatefulWidget {
  const PdfPageThumbnail({
    super.key,
    required this.path,
    required this.page,
    this.password,
    this.rotation = 0,
    this.fit = BoxFit.contain,
  });

  final String path;

  /// 0-based page index.
  final int page;
  final String? password;

  /// Extra clockwise rotation in degrees (multiples of 90).
  final int rotation;
  final BoxFit fit;

  @override
  State<PdfPageThumbnail> createState() => _PdfPageThumbnailState();
}

class _PdfPageThumbnailState extends State<PdfPageThumbnail> {
  static const _maxMemoised = 300;
  static final _memo = <String, Future<String>>{};

  Future<String>? _image;
  int? _requestedWidth;

  static Future<String> _render(String path, int page, int width, String? password) {
    final key = '$path|$page|$width';
    final cached = _memo.remove(key);
    if (cached != null) return _memo[key] = cached;

    final future = PdfEngine.renderPage(path, page, width: width, password: password);
    _memo[key] = future;
    future.catchError((Object _) {
      _memo.remove(key);
      return '';
    });
    if (_memo.length > _maxMemoised) _memo.remove(_memo.keys.first);
    return future;
  }

  @override
  void didUpdateWidget(PdfPageThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.page != widget.page) {
      _image = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final quarterTurns = (widget.rotation ~/ 90) % 4;
      final sideways = quarterTurns.isOdd;
      final logicalWidth = sideways ? constraints.maxHeight : constraints.maxWidth;
      // Round up to a 64 px bucket so small layout changes reuse the same render.
      final pixels = logicalWidth.isFinite
          ? ((logicalWidth * MediaQuery.devicePixelRatioOf(context)) / 64).ceil() * 64
          : 512;
      final width = pixels.clamp(128, 1600);
      if (_image == null || _requestedWidth != width) {
        _requestedWidth = width;
        _image = _render(widget.path, widget.page, width, widget.password);
      }

      return FutureBuilder<String>(
        future: _image,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Icon(Icons.broken_image_outlined, color: Theme.of(context).disabledColor),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return RotatedBox(
            quarterTurns: quarterTurns,
            child: Image.file(File(snapshot.data!), fit: widget.fit, gaplessPlayback: true),
          );
        },
      );
    });
  }
}
