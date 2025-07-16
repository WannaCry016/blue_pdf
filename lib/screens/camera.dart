import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:blue_pdf/screens/main_camera.dart';
import 'package:blue_pdf/state_providers.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class CameraButton extends ConsumerWidget {
  const CameraButton({super.key});

  Future<void> _startCaptureFlow(BuildContext context, WidgetRef ref) async {
  bool result = false;
  while (true) {
    final capturedFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(builder: (_) => CameraCaptureScreen(result:result)),
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
              final savedFile = await File('${cacheDir.path}/$fileName').writeAsBytes(editedBytes);

              final picturesDir = Directory('/storage/emulated/0/Pictures/BluePDF');
              if (!await picturesDir.exists()) {
                await picturesDir.create(recursive: true);
              }
              await savedFile.copy(path.join(picturesDir.path, fileName));

              final platformFile = PlatformFile(
                name: fileName,
                path: savedFile.path,
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
            child: const Center(
              child: Icon(Icons.camera_alt, size: 36, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
