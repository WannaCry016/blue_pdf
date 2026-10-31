import 'package:flutter/material.dart';

/// App bar title: the launcher icon followed by the app name.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.logoSize = 30, this.fontSize = 20});

  final double logoSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: logoSize),
        SizedBox(width: logoSize * 0.33),
        Text(
          'BLUE PDF',
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// The launcher icon as a rounded tile, the way it looks on the home screen.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 30});

  final double size;

  // The artwork carries launcher padding; enlarging it fills the tile like the real icon.
  static const _zoom = 1.3;

  @override
  Widget build(BuildContext context) {
    final pixels = (size * _zoom * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Transform.scale(
        scale: _zoom,
        // Decoded at display size rather than the full 384 px source.
        child: Image.asset('assets/logo.webp', cacheWidth: pixels, filterQuality: FilterQuality.medium),
      ),
    );
  }
}
