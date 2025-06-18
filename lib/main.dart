import 'package:flutter/material.dart';
import 'package:blue_pdf/state_providers.dart';
import 'screens/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

Future<void> initThemeNotifier() async {
  themeNotifier.value = await ThemePrefs.loadThemeMode();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: PDFUtilApp()));
}

class PDFUtilApp extends StatelessWidget {
  const PDFUtilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode mode, __) {
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
          home: const HomeScreen(),
        );
      },
    );
  }
}
