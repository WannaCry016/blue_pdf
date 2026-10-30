import 'package:blue_pdf/utils/saved_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('savedFolder', () {
    const external = 'content://com.android.externalstorage.documents/document';

    test('names the folder inside internal storage', () {
      expect(savedFolder('$external/primary%3ADocuments%2FInvoices%2Fa.pdf'), 'Documents/Invoices');
      expect(savedFolder('$external/primary%3ADownload%2Fa.pdf'), 'Download');
    });

    test('uses "Internal storage" for the root folder', () {
      expect(savedFolder('$external/primary%3Aa.pdf'), 'Internal storage');
    });

    test('labels other volumes as SD card', () {
      expect(savedFolder('$external/1A2B-3C4D%3APDFs%2Fa.pdf'), 'SD card/PDFs');
      expect(savedFolder('$external/1A2B-3C4D%3Aa.pdf'), 'SD card');
    });

    test('recognises the Downloads provider', () {
      expect(savedFolder('content://com.android.providers.downloads.documents/document/msf%3A42'), 'Download');
    });

    test('handles plain paths in shared storage', () {
      expect(savedFolder('/storage/emulated/0/Download/a.pdf'), 'Download');
      expect(savedFolder('/storage/emulated/0/a.pdf'), 'Internal storage');
    });

    test('returns null when the location is unknown', () {
      expect(savedFolder('content://com.google.android.apps.docs.storage/document/acc%3D1'), isNull);
      expect(savedFolder('/data/user/0/com.bluepdf.blue_pdf/cache/a.pdf'), isNull);
    });
  });

  group('formatFileSize', () {
    test('formats each unit', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(1023), '1023 B');
      expect(formatFileSize(1024), '1.0 KB');
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(250 * 1024), '250 KB');
      expect(formatFileSize(3 * 1024 * 1024 + 300 * 1024), '3.3 MB');
      expect(formatFileSize(2 * 1024 * 1024 * 1024), '2.0 GB');
    });
  });
}
