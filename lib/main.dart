import 'package:blue_pdf/components/slide_page_transitions.dart';
import 'package:blue_pdf/screens/splash_screen.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:blue_pdf/utils/cache_cleaner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

// Keep work before runApp to one parallel prefs + version read: the native
// launch screen stays up until the first frame, so anything here delays it.
void main() async {
  final launchedAt = DateTime.now();
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final (prefs, info) = await (SharedPreferences.getInstance(), PackageInfo.fromPlatform()).wait;
  themeNotifier.value = ThemePrefs.themeModeFrom(prefs);
  runApp(ProviderScope(child: PDFUtilApp(version: info.version)));
  // Leftovers from sessions that were killed mid-job; after the first frame so opening isn't delayed.
  binding.addPostFrameCallback((_) => clearCache(before: launchedAt).ignore());
}

class PDFUtilApp extends StatelessWidget {
  const PDFUtilApp({super.key, this.version});

  final String? version;

  static const _pageTransitions = PageTransitionsTheme(builders: {
    TargetPlatform.android: SlidePageTransitionsBuilder(),
  });

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
            pageTransitionsTheme: _pageTransitions,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            pageTransitionsTheme: _pageTransitions,
          ),
          themeMode: mode,
          home: SplashScreen(version: version),
        );
      },
    );
  }
}
