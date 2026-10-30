import 'package:blue_pdf/state_providers.dart';
import 'package:flutter_test/flutter_test.dart';

SelectedFile _file(String name) => SelectedFile(name: name, path: '/tmp/$name');

List<String> _names(SelectedFilesNotifier notifier) =>
    notifier.state.map((f) => f.name).toList();

void main() {
  group('SelectedFile', () {
    test('fromPath uses the basename as the display name', () {
      final file = SelectedFile.fromPath('/data/user/0/cache/scan_01.PDF');
      expect(file.name, 'scan_01.PDF');
      expect(file.path, '/data/user/0/cache/scan_01.PDF');
    });

    test('extension is lowercase and without the dot', () {
      expect(_file('photo.JPG').extension, 'jpg');
      expect(_file('doc.pdf').extension, 'pdf');
      expect(_file('archive.tar.gz').extension, 'gz');
    });

    test('extension is null when the name has none', () {
      expect(_file('README').extension, isNull);
    });

    test('pages of one PDF have distinct ids', () {
      const page0 = SelectedFile(name: 'Page 1', path: '/a.pdf', pageIndex: 0);
      const page1 = SelectedFile(name: 'Page 2', path: '/a.pdf', pageIndex: 1);
      expect(page0.id, isNot(page1.id));
      expect(_file('a.pdf').id, '/tmp/a.pdf');
    });

    test('copyWith keeps the page index and unspecified fields', () {
      const page = SelectedFile(name: 'Page 3', path: '/a.pdf', password: 'pw', pageIndex: 2);
      final rotated = page.copyWith(rotation: 90);
      expect(rotated.rotation, 90);
      expect(rotated.pageIndex, 2);
      expect(rotated.password, 'pw');
      expect(rotated.name, 'Page 3');
    });
  });

  group('SelectedFilesNotifier', () {
    late SelectedFilesNotifier notifier;

    setUp(() {
      notifier = SelectedFilesNotifier()
        ..setFiles([_file('a'), _file('b'), _file('c'), _file('d')]);
    });

    tearDown(() => notifier.dispose());

    test('addFiles appends in order', () {
      notifier.addFiles([_file('e'), _file('f')]);
      expect(_names(notifier), ['a', 'b', 'c', 'd', 'e', 'f']);
    });

    test('addFiles skips files already in the list', () {
      notifier.addFiles([_file('b'), _file('e'), _file('e')]);
      expect(_names(notifier), ['a', 'b', 'c', 'd', 'e']);
    });

    test('rotateClockwise steps through quarter turns', () {
      final angles = [for (var i = 0; i < 4; i++) (notifier..rotateClockwise(1)).state[1].rotation];
      expect(angles, [90, 180, 270, 0]);
      expect(notifier.state[0].rotation, 0);
    });

    test('rotation travels with the item when it moves', () {
      notifier
        ..rotateClockwise(0)
        ..move(0, 3);
      expect(notifier.state[3].name, 'a');
      expect(notifier.state[3].rotation, 90);
    });

    test('removeFileAt removes only that index', () {
      notifier.removeFileAt(1);
      expect(_names(notifier), ['a', 'c', 'd']);
    });

    test('move forward places the item at the target index', () {
      notifier.move(0, 2);
      expect(_names(notifier), ['b', 'c', 'a', 'd']);
    });

    test('move backward places the item at the target index', () {
      notifier.move(3, 1);
      expect(_names(notifier), ['a', 'd', 'b', 'c']);
    });

    test('move to the same index is a no-op', () {
      notifier.move(2, 2);
      expect(_names(notifier), ['a', 'b', 'c', 'd']);
    });

    test('state is replaced, not mutated in place', () {
      final before = notifier.state;
      notifier.move(0, 3);
      expect(identical(before, notifier.state), isFalse);
      expect(before.map((f) => f.name), ['a', 'b', 'c', 'd']);
    });

    test('clear empties the list', () {
      notifier.clear();
      expect(notifier.state, isEmpty);
    });
  });
}
