import 'package:blue_pdf/screens/home_screen.dart';
import 'package:flutter/material.dart';
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
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
          ),
        );
      }
    });
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
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Center(
              child: Text(
                "Blue PDF • Version v1.0.2",
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
