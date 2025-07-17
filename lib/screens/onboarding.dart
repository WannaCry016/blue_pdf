import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blue_pdf/screens/home_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _onIntroEnd(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101A30) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final accent = isDark ? const Color(0xFF2979FF) : const Color(0xFF1976D2);

    return IntroductionScreen(
      globalBackgroundColor: bgColor,
      pages: [
        PageViewModel(
          titleWidget: Text("Welcome to Blue PDF!", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: accent)),
          body: "Your all-in-one PDF toolkit. Merge, convert, encrypt, and more with a beautiful, easy interface.",
          image: Image.asset('assets/logo1.png', height: 180),
          decoration: PageDecoration(
            bodyTextStyle: TextStyle(fontSize: 16, color: textColor),
            titleTextStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: accent),
          ),
        ),
        PageViewModel(
          title: "Image to PDF",
          body: "Convert your images to high-quality PDFs in seconds. Perfect for receipts, notes, and more!",
          image: Image.asset('assets/2.png', height: 180),
          decoration: PageDecoration(
            bodyTextStyle: TextStyle(fontSize: 16, color: textColor),
            titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accent),
          ),
        ),
        PageViewModel(
          title: "Secure & Merge",
          body: "Encrypt your PDFs with a password, or merge multiple files into one. Your privacy, your control.",
          image: Image.asset('assets/logo2.png', height: 180),
          decoration: PageDecoration(
            bodyTextStyle: TextStyle(fontSize: 16, color: textColor),
            titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accent),
          ),
        ),
        PageViewModel(
          title: "Get Started!",
          body: "Tap Done and start using Blue PDF. All features are offline and private.",
          image: Icon(Icons.picture_as_pdf, size: 120, color: accent),
          decoration: PageDecoration(
            bodyTextStyle: TextStyle(fontSize: 16, color: textColor),
            titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: accent),
          ),
        ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      showSkipButton: true,
      skip: Text("Skip", style: TextStyle(color: accent)),
      next: Icon(Icons.arrow_forward, color: accent),
      done: Text("Done", style: TextStyle(fontWeight: FontWeight.w600, color: accent)),
      dotsDecorator: DotsDecorator(
        activeColor: accent,
        color: accent.withOpacity(0.3),
        size: const Size(10.0, 10.0),
        activeSize: const Size(22.0, 10.0),
        activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.0)),
      ),
      curve: Curves.fastOutSlowIn,
    );
  }
} 