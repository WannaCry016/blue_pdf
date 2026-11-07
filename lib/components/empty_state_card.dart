import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The home screen's "nothing selected yet" card. It sizes itself to the space it
/// is given: illustration and hint when there is room, the hint alone when the
/// screen is short (phone landscape, foldables, tablets), nothing when there is
/// no room at all, so it never squashes or clips.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.isTablet,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
  });

  final bool isTablet;
  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;

  static const message = 'Start by choosing a tool or uploading a file.';

  // Below this the illustration is too small to read as a picture.
  static const _minImage = 72.0;
  static const _border = 1.0;
  static const _compactPadding = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, area) {
      // Merged with the inherited style so measuring uses the same font and line height as the Text.
      final style = DefaultTextStyle.of(context).style.merge(TextStyle(
        fontSize: isTablet ? 18.0 : 14.0,
        fontWeight: FontWeight.w400,
        color: textColor.withValues(alpha: 0.55),
        letterSpacing: 0.2,
      ));
      final textPadding = isTablet ? 32.0 : 12.0;
      final width = math.min(area.maxWidth * (isTablet ? 0.7 : 0.9), isTablet ? 560.0 : area.maxWidth);
      final padding = (area.maxHeight * 0.08).clamp(12.0, isTablet ? 40.0 : 28.0);
      final gap = (area.maxHeight * 0.04).clamp(6.0, 16.0);

      double textHeight(double cardPadding) {
        final painter = TextPainter(
          text: TextSpan(text: message, style: style),
          textAlign: TextAlign.center,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 2,
        )..layout(maxWidth: math.max(0, width - (cardPadding + _border + textPadding) * 2));
        final height = painter.height;
        painter.dispose();
        return height;
      }

      final roomForImage = area.maxHeight - (padding + _border) * 2 - gap - textHeight(padding);
      final showImage = roomForImage >= _minImage;
      if (!showImage && area.maxHeight < textHeight(_compactPadding) + (_compactPadding + _border) * 2) {
        return const SizedBox.shrink();
      }

      final imageSize = math.min(roomForImage, area.maxWidth * (isTablet ? 0.3 : 0.42));
      return Container(
        width: width,
        padding: EdgeInsets.all(showImage ? padding : _compactPadding),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showImage) ...[
              Image.asset(
                'assets/2.webp',
                width: imageSize,
                height: imageSize,
                cacheWidth: (imageSize * MediaQuery.devicePixelRatioOf(context)).ceil(),
              ),
              SizedBox(height: gap),
            ],
            Padding(
              padding: EdgeInsets.symmetric(horizontal: textPadding),
              child: Text(message, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
            ),
          ],
        ),
      );
    });
  }
}
