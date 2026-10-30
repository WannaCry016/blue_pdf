import 'package:blue_pdf/pdf/pdf_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late Object? Function(MethodCall call) respond;

  setUp(() {
    calls = [];
    respond = (_) => null;
    messenger.setMockMethodCallHandler(PdfEngine.channel, (call) async {
      calls.add(call);
      return respond(call);
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(PdfEngine.channel, null));

  group('PdfEngine', () {
    test('inspect sends the password and parses the result', () async {
      respond = (_) => {'pageCount': 12, 'encrypted': true};

      final info = await PdfEngine.inspect('/a.pdf', password: 'pw');

      expect(info.pageCount, 12);
      expect(info.encrypted, isTrue);
      expect(calls.single.method, 'inspect');
      expect(calls.single.arguments, {'path': '/a.pdf', 'password': 'pw'});
    });

    test('imagesToPdf passes rotations and page mode, and reads skipped images', () async {
      respond = (_) => {'path': '/out.pdf', 'skipped': [1]};

      final result = await PdfEngine.imagesToPdf(['/a.jpg', '/b.jpg'], rotations: [90, 0], fitToImage: true);

      expect(result.path, '/out.pdf');
      expect(result.skipped, [1]);
      expect(calls.single.arguments, {
        'paths': ['/a.jpg', '/b.jpg'],
        'rotations': [90, 0],
        'fitToImage': true,
      });
    });

    test('extractPages sends 0-based pages in order', () async {
      respond = (_) => '/out.pdf';

      final path = await PdfEngine.extractPages('/a.pdf', [2, 0], rotations: [0, 180]);

      expect(path, '/out.pdf');
      expect(calls.single.arguments, {
        'path': '/a.pdf',
        'password': null,
        'pages': [2, 0],
        'rotations': [0, 180],
      });
    });

    test('maps native error codes to typed failures', () async {
      respond = (_) => throw PlatformException(code: 'PASSWORD_REQUIRED', message: 'needs password');

      await expectLater(
        PdfEngine.inspect('/locked.pdf'),
        throwsA(isA<PdfFailure>()
            .having((f) => f.code, 'code', PdfErrorCode.passwordRequired)
            .having((f) => f.detail, 'detail', 'needs password')),
      );
    });

    test('unknown error codes become PdfErrorCode.unknown', () async {
      respond = (_) => throw PlatformException(code: 'SOMETHING_NEW');

      await expectLater(
        PdfEngine.merge(['/a.pdf']),
        throwsA(isA<PdfFailure>().having((f) => f.code, 'code', PdfErrorCode.unknown)),
      );
    });

    test('a null result is reported as a failure', () async {
      await expectLater(
        PdfEngine.encrypt('/a.pdf', 'pw'),
        throwsA(isA<PdfFailure>().having((f) => f.code, 'code', PdfErrorCode.unknown)),
      );
    });
  });

  group('PdfFailure', () {
    test('every code has a user-facing message without technical detail', () {
      for (final code in PdfErrorCode.values) {
        final message = PdfFailure(code, 'fz_open_document failed').message;
        expect(message, isNotEmpty, reason: code.name);
        expect(message, isNot(contains('fz_')), reason: code.name);
      }
    });

    test('wire codes round-trip', () {
      for (final code in PdfErrorCode.values) {
        expect(PdfErrorCode.fromWire(code.wire), code);
      }
    });
  });
}
