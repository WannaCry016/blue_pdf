import 'package:blue_pdf/screens/home_screen.dart';
import 'package:blue_pdf/screens/onbaording_screen.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:blue_pdf/utils/cache_cleaner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// Keep work before runApp to a single prefs read: the native launch screen
// stays up until the first frame, so anything here delays the app opening.
void main() async {
  final launchedAt = DateTime.now();
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  themeNotifier.value = ThemePrefs.themeModeFrom(prefs);
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
  runApp(ProviderScope(child: PDFUtilApp(seenOnboarding: seenOnboarding)));
  // Leftovers from sessions that were killed mid-job; after the first frame so opening isn't delayed.
  binding.addPostFrameCallback((_) => clearCache(before: launchedAt).ignore());
}

class PDFUtilApp extends StatelessWidget {
  final bool seenOnboarding;

  const PDFUtilApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode mode, _) {
        return MaterialApp(
          title: 'Blue PDF',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          themeMode: mode,
          home: seenOnboarding ? const HomeScreen() : OnboardingScreen(),
        );
      },
    );
  }
}
