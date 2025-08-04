import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:blue_pdf/components/main_camera.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'; 

class CameraButton extends ConsumerWidget {
  final double iconSize;
  const CameraButton({super.key, this.iconSize = 36});

  Future<void> _startCaptureFlow(BuildContext context, WidgetRef ref) async {
    bool result = false;
    while (true) {
      final capturedFile = await Navigator.push<File>(
        context,
        MaterialPageRoute(builder: (_) => CameraCaptureScreen(result: result)),
      );

      if (capturedFile == null) break;

      final imageBytes = await capturedFile.readAsBytes();

      result = (await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ProImageEditor.memory(
            imageBytes,
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (Uint8List editedBytes) async {
                final timestamp = DateTime.now().millisecondsSinceEpoch;
                final fileName = 'BluePDF_$timestamp.jpg';

                final cacheDir = await getTemporaryDirectory();
                final tempPath = path.join(cacheDir.path, fileName);

                // ✅ Fix orientation and compress image
                final fixedBytes = await FlutterImageCompress.compressWithList(
                  editedBytes,
                  autoCorrectionAngle: true,  // 💡 ensures EXIF-based rotation is handled
                  format: CompressFormat.jpeg,
                  quality: 100,
                );

                final savedFile = await File(tempPath).writeAsBytes(fixedBytes);

                // ✅ Save to gallery folder
                final picturesDir = Directory('/storage/emulated/0/Pictures/BluePDF');
                if (!await picturesDir.exists()) {
                  await picturesDir.create(recursive: true);
                }

                final finalPath = path.join(picturesDir.path, fileName);
                await savedFile.copy(finalPath);

                // ✅ For your PDF logic
                final platformFile = PlatformFile(
                  name: fileName,
                  path: savedFile.path, // use savedFile.path (cache) or finalPath (gallery)
                  size: await savedFile.length(),
                );

                ref.read(imageToPdfFilesProvider.notifier).addFiles([platformFile]);

                Navigator.pop(context, true); // ✅ Return true
              },
            ),
          ),
        ),
      ))!;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: GestureDetector(
          onTap: () async {
            final selectedTool = ref.read(selectedToolProvider);
            if (selectedTool != "Image to PDF") {
              ref.read(selectedToolProvider.notifier).state = "Image to PDF";
            }

            await _startCaptureFlow(context, ref); // 🔁 loop flow
          },
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Icon(Icons.camera_alt, size: iconSize, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
