import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blue_pdf/main.dart';
import 'package:blue_pdf/state_providers.dart';

class CameraCaptureScreen extends ConsumerStatefulWidget {
  final bool result; 

  const CameraCaptureScreen({super.key, required this.result});

  @override
  ConsumerState<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends ConsumerState<CameraCaptureScreen> {
  late CameraController _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isFlashOn = false;
  CameraLensDirection _currentLens = CameraLensDirection.back;

  Offset? _tapOffset;
  bool _showFocusRect = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera(_currentLens);
    if (widget.result) {
      // Show a simple SnackBar-style overlay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Image added and saved successfully",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF1E1E2E), // Elegant deep navy/gray
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            elevation: 4,
          ),
        );
      });
    }
  }

  Future<void> _initializeCamera(CameraLensDirection direction) async {
    final camera = cameras.firstWhere((c) => c.lensDirection == direction);
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
        _isFlashOn = false;
      });
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  void _toggleFlash() async {
    if (!_controller.value.isInitialized) return;
    try {
      _isFlashOn
          ? await _controller.setFlashMode(FlashMode.off)
          : await _controller.setFlashMode(FlashMode.torch);
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      debugPrint("Flash error: $e");
    }
  }

  void _flipCamera() async {
    if (_isCapturing) return;
    setState(() {
      _isInitialized = false;
      _currentLens = _currentLens == CameraLensDirection.back
          ? CameraLensDirection.front
          : CameraLensDirection.back;
    });

    await _controller.dispose();
    await _initializeCamera(_currentLens);
  }

  Future<void> _takePicture() async {
    if (_isCapturing || !_controller.value.isInitialized) return;
    setState(() => _isCapturing = true);

    try {
      final file = await _controller.takePicture();
      if (mounted) {
        Navigator.pop(context, File(file.path)); // ✅ Only return, don't save
      }
    } catch (e) {
      debugPrint("Capture failed: $e");
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  void _handleTapFocus(TapDownDetails details, BoxConstraints constraints) {
    if (!_controller.value.isInitialized) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localPoint = box.globalToLocal(details.globalPosition);
    final double dx = details.localPosition.dx / constraints.maxWidth;
    final double dy = details.localPosition.dy / constraints.maxHeight;

    final Offset focusPoint = Offset(dx, dy);

    setState(() {
      _tapOffset = localPoint;
      _showFocusRect = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showFocusRect = false);
    });

    _controller.setFocusPoint(focusPoint).catchError((e) {
      debugPrint("Focus error: $e");
    });
    _controller.setExposurePoint(focusPoint).catchError((e) {
      debugPrint("Exposure error: $e");
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageCount = ref.watch(imageToPdfFilesProvider).length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 30),
                AspectRatio(
                  aspectRatio: 9 / 16,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTapDown: (details) =>
                            _handleTapFocus(details, constraints),
                        child: Stack(
                          children: [
                            CameraPreview(_controller),
                            if (_showFocusRect && _tapOffset != null)
                              Positioned(
                                left: _tapOffset!.dx - 20,
                                top: _tapOffset!.dy - 20,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                    shape: BoxShape.rectangle,
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 10,
                              left: 20,
                              child: IconButton(
                                icon: Icon(
                                  _isFlashOn
                                      ? Icons.flash_on
                                      : Icons.flash_off,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                onPressed: _toggleFlash,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Flip camera button
                      IconButton(
                        icon: const Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: _flipCamera,
                      ),
                      const SizedBox(width: 50),

                      // Capture button
                      GestureDetector(
                        onTap: _takePicture,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: _isCapturing ? 60 : 75,
                          height: _isCapturing ? 60 : 75,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 50),

                      // Image count display
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$imageCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
