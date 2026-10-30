import 'dart:io';

import 'package:blue_pdf/utils/cache_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late DateTime launchedAt;

  File file(String relative, {required bool old}) {
    final f = File(p.join(root.path, relative))..createSync(recursive: true);
    if (old) f.setLastModifiedSync(launchedAt.subtract(const Duration(hours: 1)));
    return f;
  }

  setUp(() {
    root = Directory.systemTemp.createTempSync('cache_cleaner_test');
    launchedAt = DateTime.now().subtract(const Duration(minutes: 1));
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('removes files from earlier sessions and keeps new ones', () async {
    final stale = file('merged_1.pdf', old: true);
    final staleNested = file('file_picker/123/a.pdf', old: true);
    final fresh = file('file_picker/456/b.pdf', old: false);
    final freshThumb = file('thumbs/x.jpg', old: false);

    await clearCache(before: launchedAt, directory: root);

    expect(stale.existsSync(), isFalse);
    expect(staleNested.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
    expect(freshThumb.existsSync(), isTrue);
    expect(root.existsSync(), isTrue);
  });

  test('keeps a folder created this session even when it is still empty', () async {
    final outputs = Directory(p.join(root.path, 'outputs'))..createSync();

    await clearCache(before: launchedAt, directory: root);

    expect(outputs.existsSync(), isTrue);
  });

  test('a missing cache folder is not an error', () async {
    await clearCache(before: launchedAt, directory: Directory(p.join(root.path, 'nope')));
  });
}
