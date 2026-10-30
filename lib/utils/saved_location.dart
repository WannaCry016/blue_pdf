/// Folder of a document saved through the system file picker, when the URI
/// reveals it (e.g. `Download` or `Documents/Invoices`), otherwise null.
String? savedFolder(String saved) {
  final uri = Uri.tryParse(saved);
  if (uri == null) return null;

  if (uri.scheme == 'content') {
    if (uri.host == 'com.android.providers.downloads.documents') return 'Download';
    if (uri.host != 'com.android.externalstorage.documents' || uri.pathSegments.isEmpty) {
      return null;
    }
    // Document IDs look like "primary:Download/Invoices/file.pdf".
    final documentId = uri.pathSegments.last;
    final separator = documentId.indexOf(':');
    if (separator < 0) return null;
    final volume = documentId.substring(0, separator);
    final relative = documentId.substring(separator + 1);
    final slash = relative.lastIndexOf('/');
    final folder = slash < 0 ? '' : relative.substring(0, slash);
    if (volume == 'primary') return folder.isEmpty ? 'Internal storage' : folder;
    return folder.isEmpty ? 'SD card' : 'SD card/$folder';
  }

  const storageRoot = '/storage/emulated/0/';
  if (saved.startsWith(storageRoot)) {
    final relative = saved.substring(storageRoot.length);
    final slash = relative.lastIndexOf('/');
    return slash < 0 ? 'Internal storage' : relative.substring(0, slash);
  }
  return null;
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
}
