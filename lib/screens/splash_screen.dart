import 'dart:async';

import 'package:blue_pdf/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _logo = AssetImage('assets/splash_logo.webp');

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.version, this.next = const HomeScreen()});

  final String? version;
  final Widget next;

  static const duration = Duration(milliseconds: 1500);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Timer _timer;
  bool _logoRequested = false;

  @override
  void initState() {
    super.initState();
    // Keep the native launch screen, which shows the same logo, until ours is decoded.
    WidgetsBinding.instance.deferFirstFrame();
    _timer = Timer(SplashScreen.duration, _openNext);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_logoRequested) return;
    _logoRequested = true;
    precacheImage(_logo, context).whenComplete(WidgetsBinding.instance.allowFirstFrame);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _openNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => widget.next,
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final version = widget.version;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1115),
        body: Stack(
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
