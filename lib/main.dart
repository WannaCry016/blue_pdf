import 'package:blue_pdf/screens/splash_screen.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

Future<void> initThemeNotifier() async {
  themeNotifier.value = await ThemePrefs.loadThemeMode();
}
late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
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
          home: const SplashScreen(),
        );
      },
    );
  }
}
