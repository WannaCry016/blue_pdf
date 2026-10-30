import 'package:file_saver/file_saver.dart';

/// Copies a finished PDF into shared storage. Both ways stream the file from
/// disk off the main thread, so large files don't cost memory or frames.
class PdfSaver {
  const PdfSaver();

  /// Our folder inside Downloads, used unless the user picks another.
  static const appFolder = 'BLUE PDF';
  static const appFolderLabel = 'Download/$appFolder';

  /// Saves into [appFolderLabel] with no UI. An existing file is never
  /// overwritten: Android saves as "name (1).pdf" instead. Returns the
  /// MediaStore URI of the new file.
  Future<String?> saveToAppFolder({required String name, required String sourcePath}) {
    return FileSaver.instance.saveToDownloads(
      name: name,
      filePath: sourcePath,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
      subfolder: appFolder,
    );
  }

  /// Lets the user choose the folder (and name) in the system picker.
  /// Returns the document URI, or null when they back out.
  Future<String?> saveWithPicker({required String name, required String sourcePath, String? initialDirectory}) {
    return FileSaver.instance.saveAs(
      name: name,
      filePath: sourcePath,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
      initialDirectory: initialDirectory,
    );
  }
}
