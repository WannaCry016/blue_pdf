import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
enum ViewMode { list, grid }

// Page size enum for Image to PDF
enum PageSize { a4, fit }

var selectedToolProvider = StateProvider<String?>((ref) => null);
var recentFilesProvider = StateProvider<List<String>>((ref) => []);
var isFileLoadingProvider = StateProvider<bool>((ref) => false);
final isProcessingProvider = StateProvider<bool>((ref) => false);
final savePathProvider = StateProvider<String?>((ref) => null);
final mergedPdfBytesProvider = StateProvider<Uint8List?>((ref) => null);
final cachePathProvider = StateProvider<String?>((ref) => null);
final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.list);
final pageSizeProvider = StateProvider<PageSize>((ref) => PageSize.a4);

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

/// A file chosen by the user (picked, captured, or generated), always backed by a local path.
class SelectedFile {
  final String name;
  final String path;

  const SelectedFile({required this.name, required this.path});

  factory SelectedFile.fromPath(String path) =>
      SelectedFile(name: p.basename(path), path: path);

  String? get extension {
    final ext = p.extension(name);
    return ext.isEmpty ? null : ext.substring(1).toLowerCase();
  }

  /// Picked files without a local path (content URIs) are copied into the cache.
  static Future<SelectedFile> fromPicked(PlatformFile file) async {
    final localPath = file.path;
    if (localPath != null) return SelectedFile(name: file.name, path: localPath);

    final dir = await getTemporaryDirectory();
    final copy = File(p.join(dir.path, '${DateTime.now().microsecondsSinceEpoch}_${file.name}'));
    await copy.writeAsBytes(await file.readAsBytes());
    return SelectedFile(name: file.name, path: copy.path);
  }
}

var selectedFilePathProvider = StateProvider<String?>((ref) => null);
final imageToPdfFilesProvider =
    StateNotifierProvider<SelectedFilesNotifier, List<SelectedFile>>(
        (ref) => SelectedFilesNotifier());

final mergePdfFilesProvider =
    StateNotifierProvider<SelectedFilesNotifier, List<SelectedFile>>(
        (ref) => SelectedFilesNotifier());

final encryptPdfFilesProvider =
    StateNotifierProvider<SelectedFilesNotifier, List<SelectedFile>>(
        (ref) => SelectedFilesNotifier());

final splitPdfFilesProvider =
    StateNotifierProvider<SelectedFilesNotifier, List<SelectedFile>>(
        (ref) => SelectedFilesNotifier());

final reorderPdfFilesProvider =
    StateNotifierProvider<SelectedFilesNotifier, List<SelectedFile>>(
        (ref) => SelectedFilesNotifier());

class SelectedFilesNotifier extends StateNotifier<List<SelectedFile>> {
  SelectedFilesNotifier() : super([]);

  void setFiles(List<SelectedFile> files) {
    state = files;
  }

  void addFiles(List<SelectedFile> files) {
    state = [...state, ...files];
  }

  void removeFileAt(int index) {
    final newList = [...state]..removeAt(index);
    state = newList;
  }

  /// Moves the item at [from] so it ends up at index [to] in the new list.
  void move(int from, int to) {
    final updatedList = [...state];
    final item = updatedList.removeAt(from);
    updatedList.insert(to, item);
    state = updatedList;
  }

  void clear() {
    state = [];
  }
}
