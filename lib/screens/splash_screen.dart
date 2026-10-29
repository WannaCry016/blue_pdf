import 'package:blue_pdf/screens/home_screen.dart';
import 'package:blue_pdf/screens/onbaording_screen.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            seenOnboarding ? const HomeScreen() : OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115), // Premium dark background
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Centered logo
          Center(
            child: Image.asset(
              'assets/logo1.png',
              width: 200,
            ),
          ),
          const Spacer(),
          // Version label at bottom
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) => Text(
                  snapshot.hasData
                      ? "Blue PDF • Version v${snapshot.data!.version}"
                      : "Blue PDF",
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
    );
  }
}
