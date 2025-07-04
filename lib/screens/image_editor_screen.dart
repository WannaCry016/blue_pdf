// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:pro_image_editor/pro_image_editor.dart';

// class ImageEditorScreen extends StatelessWidget {
//   final Uint8List imageData;

//   const ImageEditorScreen({
//     super.key,
//     required this.imageData,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return ProImageEditor.memory(
//       imageData,
//       // This is the correct callback for when the user taps the "Done" button.
//       onImageEditingComplete: (Uint8List editedImageBytes) {
//         // When editing is complete, we pop the screen and pass the
//         // new image data back to the previous screen.
//         Navigator.of(context).pop(editedImageBytes);
//       }, callbacks: null,
//       // IMPORTANT: The editor has its own built-in "Close" button in the
//       // top-left corner. When the user taps it, the editor automatically
//       // calls `Navigator.pop(context)`, which will return `null` to the
//       // screen that pushed it. This is why an `onCloseEditor` parameter
//       // is not needed.
//     );
//   }
// }