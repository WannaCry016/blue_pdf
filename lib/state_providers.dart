import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

var selectedToolProvider = StateProvider<String?>((ref) => null);
var recentFilesProvider = StateProvider<List<String>>((ref) => []);
var isFileLoadingProvider = StateProvider<bool>((ref) => false);
final isProcessingProvider = StateProvider<bool>((ref) => false);
final savePathProvider = StateProvider<String?>((ref) => null);
final mergedPdfBytesProvider = StateProvider<Uint8List?>((ref) => null);
final cachePathProvider = StateProvider<String?>((ref) => null);

class ThemePrefs {
  static const _themeKey = 'theme_mode';

  // Save theme mode
  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name); // mode.name returns 'light', 'dark', or 'system'
  }

  // Load theme mode
  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_themeKey) ?? 'light';

    switch (themeStr) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }
}


var selectedFilePathProvider = StateProvider<String?>((ref) => null);
final imageToPdfFilesProvider =
    StateNotifierProvider<SelectedFilesNotifier, List<PlatformFile>>(
        (ref) => SelectedFilesNotifier());

final mergePdfFilesProvider =
    StateNotifierProvider<SelectedFilesNotifier, List<PlatformFile>>(
        (ref) => SelectedFilesNotifier());

final encryptPdfFilesProvider =
    StateNotifierProvider<SelectedFilesNotifier, List<PlatformFile>>(
        (ref) => SelectedFilesNotifier());

final unlockPdfFilesProvider =
    StateNotifierProvider<SelectedFilesNotifier, List<PlatformFile>>(
        (ref) => SelectedFilesNotifier());


class SelectedFilesNotifier extends StateNotifier<List<PlatformFile>> {
  SelectedFilesNotifier() : super([]);

  void setFiles(List<PlatformFile> files) {
    state = files;
  }

  void addFiles(List<PlatformFile> files) async {
    // Show file names immediately
    state = [...state, ...files];

    // Start background loading of bytes
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      if (file.path != null) {
        final fileData = await File(file.path!).readAsBytes();

        final updatedFile = PlatformFile(
          name: file.name,
          path: file.path,
          bytes: fileData,
          size: fileData.length,
        );

        // Update only the one file in state (preserving index order)
        state = [
          for (int j = 0; j < state.length; j++)
            if (j == state.length - files.length + i)
              updatedFile
            else
              state[j],
        ];
      }
    }
  }

  void removeFileAt(int index) {
    final newList = [...state]..removeAt(index);
    state = newList;
  }

  void reorder(int oldIndex, int newIndex) {
    final updatedList = [...state];
    if (newIndex > oldIndex) newIndex--;
    final item = updatedList.removeAt(oldIndex);
    updatedList.insert(newIndex, item);
    state = updatedList;
  }

  void clear() {
    state = [];
  }
}

final recentCreatedFilesProvider = StateNotifierProvider<RecentFilesNotifier, List<String>>(
  (ref) => RecentFilesNotifier(),
);


class RecentFilesNotifier extends StateNotifier<List<String>> {
  static const _key = 'recent_created_files';

  RecentFilesNotifier() : super([]) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final files = prefs.getStringList(_key) ?? [];
    state = files;
  }

  void _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state);
  }

  void addFile(String path) {
    if (!state.contains(path)) {
      state = [path, ...state];
      _saveToPrefs();
    }
  }

  void removeFile(String path) {
    state = state.where((p) => p != path).toList();
    _saveToPrefs();
  }

  void clear() {
    state = [];
    _saveToPrefs();
  }
}
