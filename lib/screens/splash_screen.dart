import 'package:blue_pdf/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _logo = AssetImage('assets/splash_logo.webp');

/// Shows the splash over [next] while [next] builds and decodes its images
/// underneath, then fades away: after [minVisible], or once loading is done
/// if that takes longer.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.version, this.next = const HomeScreen()});

  final String? version;
  final Widget next;

  /// Long enough to see the logo and version rather than a flash.
  static const minVisible = Duration(seconds: 1);

  /// Upper bound on waiting for [next]'s images, so a slow decode never holds the app.
  static const maxWait = Duration(seconds: 2);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: 1,
  );
  bool _logoRequested = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    // Keep the native launch screen, which shows the same logo, until ours is decoded.
    WidgetsBinding.instance.deferFirstFrame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_logoRequested) return;
    _logoRequested = true;
    precacheImage(_logo, context).whenComplete(() {
      WidgetsBinding.instance.allowFirstFrame();
      _revealWhenReady();
    });
  }

  Future<void> _revealWhenReady() async {
    final minimum = Future<void>.delayed(SplashScreen.minVisible);
    final loading = Stopwatch()..start();
    await WidgetsBinding.instance.endOfFrame;
    final images = PaintingBinding.instance.imageCache;
    while (images.pendingImageCount > 0 && loading.elapsed < SplashScreen.maxWait) {
      await WidgetsBinding.instance.endOfFrame;
    }
    await minimum;
    if (!mounted) return;
    await _fade.reverse();
    if (mounted) setState(() => _gone = true);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Same tree shape before and after, so [next] keeps its state when the splash goes.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.next,
        if (!_gone) FadeTransition(opacity: _fade, child: _SplashView(version: widget.version)),
      ],
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView({this.version});

  final String? version;

  @override
  Widget build(BuildContext context) {
    final version = this.version;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: const Color(0xFF0F1115),
        child: Stack(
          children: [
            // Centred on the whole screen so it lines up with the native launch screen.
            const Center(child: Image(image: _logo, width: 200)),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    version == null ? 'Blue PDF' : 'Blue PDF • Version v$version',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
