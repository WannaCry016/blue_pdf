import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blue_pdf/state_providers.dart';

class ImageViewerScreen extends ConsumerWidget {
  const ImageViewerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filePath = ref.watch(selectedFilePathProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Image Viewer')),
      body: filePath == null
          ? const Center(child: Text("No file selected."))
          : Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  File(filePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
    );
  }
}
