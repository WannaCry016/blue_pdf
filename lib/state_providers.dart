import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
enum ViewMode { list, grid }

// Page size enum for Image to PDF
enum PageSize { a4, fit }

final selectedToolProvider = StateProvider<String?>((ref) => null);
final isProcessingProvider = StateProvider<bool>((ref) => false);
final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.list);
final pageSizeProvider = StateProvider<PageSize>((ref) => PageSize.a4);

class ThemePrefs {
  static const _themeKey = 'theme_mode';

  // Save theme mode
  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name); // mode.name returns 'light', 'dark', or 'system'
  }

  static ThemeMode themeModeFrom(SharedPreferences prefs) =>
      switch (prefs.getString(_themeKey)) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
}

/// A file chosen by the user (picked, captured, or generated), always backed by a local path.
class SelectedFile {
  final String name;
  final String path;

  /// Password that unlocked this PDF, if it is protected.
  final String? password;

  /// Extra clockwise rotation chosen by the user (0, 90, 180 or 270).
  final int rotation;

  /// Set when this entry is a single page (0-based) of the PDF at [path].
  final int? pageIndex;

  const SelectedFile({
    required this.name,
    required this.path,
    this.password,
    this.rotation = 0,
    this.pageIndex,
  });

  factory SelectedFile.fromPath(String path) =>
      SelectedFile(name: p.basename(path), path: path);

  /// Unique within a list, even when several entries are pages of one PDF.
  String get id => pageIndex == null ? path : '$path#$pageIndex';

  SelectedFile copyWith({String? name, String? path, String? password, int? rotation}) =>
      SelectedFile(
        name: name ?? this.name,
        path: path ?? this.path,
        password: password ?? this.password,
        rotation: rotation ?? this.rotation,
        pageIndex: pageIndex,
      );

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

  /// Appends [files], skipping any already in the list (ids must stay unique).
  void addFiles(List<SelectedFile> files) {
    final ids = {for (final f in state) f.id};
    state = [...state, ...files.where((f) => ids.add(f.id))];
  }

  void removeFileAt(int index) {
    final newList = [...state]..removeAt(index);
    state = newList;
  }

  void rotateClockwise(int index) {
    final file = state[index];
    state = [...state]..[index] = file.copyWith(rotation: (file.rotation + 90) % 360);
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
