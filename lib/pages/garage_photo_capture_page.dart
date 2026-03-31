// lib/pages/garage_photo_capture_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:easy_localization/easy_localization.dart';

class GaragePhotoCapturePage extends StatefulWidget {
  const GaragePhotoCapturePage({Key? key}) : super(key: key);

  @override
  _GaragePhotoCapturePageState createState() => _GaragePhotoCapturePageState();
}

class _GaragePhotoCapturePageState extends State<GaragePhotoCapturePage> {
  CameraController? _controller;
  bool _ready = false;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) Navigator.pop(context, null);
      return;
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) Navigator.pop(context, null);
      return;
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
    await _controller!.initialize();
    if (!mounted) return;
    setState(() => _ready = true);
  }

  Future<void> _capture() async {
    if (_capturing || _controller == null) return;
    setState(() => _capturing = true);
    try {
      final xFile = await _controller!.takePicture();
      final docsDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${docsDir.path}/garage_photos');
      await photosDir.create(recursive: true);
      final permanentPath = '${photosDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(xFile.path).copy(permanentPath);
      try {
        await File(xFile.path).delete();
      } catch (_) {}
      if (mounted) Navigator.pop(context, permanentPath);
    } catch (e) {
      if (mounted) {
        setState(() => _capturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'garage.captureFailed'.tr(namedArgs: {'error': e.toString()}),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final size = MediaQuery.of(context).size;
    final scale = 1 / (_controller!.value.aspectRatio * size.aspectRatio);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'garage.addPhotoTitle'.tr(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: CameraPreview(_controller!),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _capturing ? null : _capture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEF5350),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: _capturing
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
