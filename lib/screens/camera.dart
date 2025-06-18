import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:blue_pdf/state_providers.dart';

class CameraButton extends ConsumerWidget {
  const CameraButton({super.key});

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
              // Auto-switch silently without any dialog
              ref.read(selectedToolProvider.notifier).state = "Image to PDF";
            }

            await _startCameraLoop(ref);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
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
                  child: Icon(
                    Icons.camera_alt,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startCameraLoop(WidgetRef ref) async {
    final picker = ImagePicker();
    final directory = await getApplicationDocumentsDirectory();

    while (true) {
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile == null) break; // user exited camera

      final file = File(pickedFile.path);
      final fileName = 'captured_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await file.copy('${directory.path}/$fileName');

      final platformFile = PlatformFile(
        name: fileName,
        path: savedFile.path,
        size: await savedFile.length(),
      );

      ref.read(imageToPdfFilesProvider.notifier).addFiles([platformFile]);
    }
  }
}
