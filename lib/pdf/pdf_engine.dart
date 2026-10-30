import 'package:flutter/services.dart';

/// Failure codes raised by the native engine (see android/app/src/main/cpp/pdf_ops.h).
enum PdfErrorCode {
  passwordRequired('PASSWORD_REQUIRED'),
  wrongPassword('WRONG_PASSWORD'),
  alreadyEncrypted('ALREADY_ENCRYPTED'),
  openFailed('OPEN_FAILED'),
  processFailed('PROCESS_FAILED'),
  writeFailed('WRITE_FAILED'),
  noPages('NO_PAGES'),
  invalidArgument('INVALID_ARGUMENT'),
  outOfMemory('OUT_OF_MEMORY'),
  unknown('UNKNOWN');

  const PdfErrorCode(this.wire);

  final String wire;

  static PdfErrorCode fromWire(String code) =>
      values.firstWhere((c) => c.wire == code, orElse: () => unknown);
}

class PdfFailure implements Exception {
  const PdfFailure(this.code, [this.detail]);

  final PdfErrorCode code;

  /// Technical detail for logs; never shown to the user.
  final String? detail;

  String get message => switch (code) {
        PdfErrorCode.passwordRequired => 'This PDF is password-protected.',
        PdfErrorCode.wrongPassword => 'That password is incorrect.',
        PdfErrorCode.alreadyEncrypted => 'This PDF is already password-protected.',
        PdfErrorCode.openFailed => "This file couldn't be opened. It may be damaged or not a PDF.",
        PdfErrorCode.processFailed => "This PDF couldn't be processed. It may be damaged.",
        PdfErrorCode.writeFailed => "The result couldn't be written. Check that your phone has free space.",
        PdfErrorCode.noPages => 'There was nothing to add: no readable pages or images.',
        PdfErrorCode.invalidArgument => 'That selection is not valid. Please check it and try again.',
        PdfErrorCode.outOfMemory => 'This file is too large to process on this device.',
        PdfErrorCode.unknown => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'PdfFailure(${code.wire}${detail == null ? '' : ': $detail'})';
}

class PdfInfo {
  const PdfInfo({required this.pageCount, required this.encrypted});

  final int pageCount;

  /// Whether a user password is needed to open the document.
  final bool encrypted;
}

class ImagesToPdfResult {
  const ImagesToPdfResult({required this.path, required this.skipped});

  final String path;

  /// Indices of input images that could not be read.
  final List<int> skipped;
}

class SavedDocument {
  const SavedDocument({this.name, this.size});

  final String? name;
  final int? size;
}

/// Typed access to the MuPDF engine. Page numbers are 0-based throughout.
class PdfEngine {
  PdfEngine._();

  static const channel = MethodChannel('com.bluepdf.channel/pdf');

  static Future<PdfInfo> inspect(String path, {String? password}) async {
    final result = await _invoke<Map<Object?, Object?>>('inspect', {
      'path': path,
      'password': password,
    });
    return PdfInfo(
      pageCount: result['pageCount']! as int,
      encrypted: result['encrypted']! as bool,
    );
  }

  /// Rotations are clockwise degrees per image, applied after EXIF orientation.
  static Future<ImagesToPdfResult> imagesToPdf(
    List<String> paths, {
    List<int> rotations = const [],
    bool fitToImage = false,
  }) async {
    final result = await _invoke<Map<Object?, Object?>>('imagesToPdf', {
      'paths': paths,
      'rotations': rotations,
      'fitToImage': fitToImage,
    });
    return ImagesToPdfResult(
      path: result['path']! as String,
      skipped: (result['skipped']! as List<Object?>).cast<int>(),
    );
  }

  static Future<String> merge(List<String> paths, {List<String?> passwords = const []}) =>
      _invoke<String>('merge', {'paths': paths, 'passwords': passwords});

  /// Writes [pages] of [path] in the given order; [rotations] are added per page.
  static Future<String> extractPages(
    String path,
    List<int> pages, {
    String? password,
    List<int> rotations = const [],
  }) =>
      _invoke<String>('extractPages', {
        'path': path,
        'password': password,
        'pages': pages,
        'rotations': rotations,
      });

  static Future<String> encrypt(String path, String newPassword) =>
      _invoke<String>('encrypt', {'path': path, 'newPassword': newPassword});

  /// Returns a cached JPEG of [page] rendered [width] pixels wide.
  static Future<String> renderPage(String path, int page, {required int width, String? password}) =>
      _invoke<String>('renderPage', {
        'path': path,
        'page': page,
        'width': width,
        'password': password,
      });

  /// Name and size of a document saved through the system file picker.
  static Future<SavedDocument> describeSaved(String uri) async {
    final result = await _invoke<Map<Object?, Object?>>('describeSaved', {'uri': uri});
    return SavedDocument(name: result['name'] as String?, size: result['size'] as int?);
  }

  static Future<T> _invoke<T>(String method, Map<String, Object?> arguments) async {
    try {
      final result = await channel.invokeMethod<T>(method, arguments);
      if (result == null) throw PdfFailure(PdfErrorCode.unknown, '$method returned null');
      return result;
    } on PlatformException catch (e) {
      throw PdfFailure(PdfErrorCode.fromWire(e.code), e.message);
    }
  }
}
