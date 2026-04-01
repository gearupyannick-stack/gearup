// lib/pages/garage_camera_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/garage_service.dart';
import '../services/audio_feedback.dart';
import '../services/car_recognition_service.dart';
import '../services/premium_service.dart';
import 'premium_page.dart';

class GarageCameraPage extends StatefulWidget {
  final List<Map<String, String>> allCars;
  const GarageCameraPage({Key? key, required this.allCars}) : super(key: key);

  @override
  _GarageCameraPageState createState() => _GarageCameraPageState();
}

class _GarageCameraPageState extends State<GarageCameraPage> {
  CameraController? _controller;
  CameraDescription? _backCamera;
  ObjectDetector? _objectDetector;
  Timer? _detectionTimer;

  bool _cameraReady = false;
  bool _formOpen = false;
  bool _capturing = false;

  List<Rect> _scaledRects = [];
  String _statusText = '';

  List<dynamic>? _cachedCsvRows;

  Future<List<dynamic>> _getCsvRows() async {
    if (_cachedCsvRows != null) return _cachedCsvRows!;
    final csvStr = await rootBundle.loadString('assets/cars.csv');
    _cachedCsvRows = const CsvToListConverter(eol: '\n').convert(csvStr);
    return _cachedCsvRows!;
  }

  @override
  void initState() {
    super.initState();
    _initDetector();
    _initCamera();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _controller?.dispose();
    _objectDetector?.close();
    super.dispose();
  }

  void _initDetector() {
    _objectDetector = ObjectDetector(
      options: ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: true,
      ),
    );
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('garage.cameraPermission'.tr())),
        );
        Navigator.pop(context);
      }
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    _backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      _backCamera!,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (!mounted) return;

    setState(() => _cameraReady = true);
    setState(() => _statusText = 'garage.pointCamera'.tr());
    _startPeriodicDetection();
  }

  void _startPeriodicDetection() {
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      if (!_formOpen && !_capturing && _cameraReady) {
        _detectFromPhoto();
      }
    });
  }

  Future<void> _detectFromPhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final xFile = await _controller!.takePicture();
      if (!mounted) return;

      final inputImage = InputImage.fromFilePath(xFile.path);
      final objects = await _objectDetector!.processImage(inputImage);

      // Read actual image size for correct scaling
      final imgBytes = await File(xFile.path).readAsBytes();
      final decodedImage = await decodeImageFromList(imgBytes);
      final imgW = decodedImage.width.toDouble();
      final imgH = decodedImage.height.toDouble();

      // Clean up temp file
      try { await File(xFile.path).delete(); } catch (_) {}

      if (!mounted) return;

      final screenSize = MediaQuery.of(context).size;
      final scaleX = screenSize.width / imgW;
      final scaleY = screenSize.height / imgH;

      setState(() {
        _scaledRects = objects.map((o) {
          final r = o.boundingBox;
          return Rect.fromLTRB(
            r.left * scaleX,
            r.top * scaleY,
            r.right * scaleX,
            r.bottom * scaleY,
          );
        }).toList();

        if (objects.isEmpty) {
          _statusText = 'garage.pointCamera'.tr();
        } else if (objects.length == 1) {
          _statusText = 'garage.carDetected'.tr();
        } else {
          _statusText = 'garage.objectsDetected'.tr(namedArgs: {'count': objects.length.toString()});
        }
      });
    } catch (_) {}
  }

  Future<void> _onCapture() async {
    if (_capturing || _formOpen) return;

    setState(() { _capturing = true; });
    try { AudioFeedback.instance.playEvent(SoundEvent.tap); } catch (_) {}

    try {
      // Take the actual photo to save
      final xFile = await _controller!.takePicture();

      // Save permanently
      final docsDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${docsDir.path}/garage_photos');
      await photosDir.create(recursive: true);
      final permanentPath = '${photosDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(xFile.path).copy(permanentPath);
      try { await File(xFile.path).delete(); } catch (_) {}

      if (!mounted) return;

      final csvRows = await _getCsvRows();

      if (!mounted) return;

      setState(() {
        _formOpen = true;
        _statusText = 'garage.fillDetails'.tr();
      });

      final result = await _showCarEntryForm(permanentPath, csvRows: csvRows);

      if (result != true) {
        // User cancelled — delete saved photo
        try { await File(permanentPath).delete(); } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _formOpen = false;
        _capturing = false;
        _scaledRects = [];
        _statusText = 'garage.pointCamera'.tr();
      });

      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _capturing = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('garage.captureFailed'.tr(namedArgs: {'error': e.toString()}))),
        );
      }
    }
  }

  Future<bool?> _showCarEntryForm(String photoPath, {List<dynamic>? csvRows}) {
    final brandCtrl    = TextEditingController();
    final modelCtrl    = TextEditingController();
    final yearCtrl     = TextEditingController();
    final engineCtrl   = TextEditingController();
    final topSpeedCtrl = TextEditingController();
    final accelCtrl    = TextEditingController();
    final hpCtrl       = TextEditingController();
    final priceCtrl    = TextEditingController();
    final originCtrl   = TextEditingController();
    final featureCtrl  = TextEditingController();
    final descCtrl     = TextEditingController();

    InputDecoration fieldDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30),
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    const style = TextStyle(color: Colors.white, fontSize: 14);

    // Chip is always available — Gemini fills everything on tap (premium only)
    bool autoFillLoading = false;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.90,
            minChildSize: 0.5,
            maxChildSize: 0.97,
            builder: (_, scroll) => ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Photo preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(photoPath),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'garage.addCarTitle'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                // Auto-fill chip
                GestureDetector(
                  onTap: autoFillLoading
                      ? null
                      : () async {
                          if (!PremiumService.instance.isPremium) {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(builder: (_) => const PremiumPage()),
                            );
                            return;
                          }
                          setModalState(() => autoFillLoading = true);
                          try {
                            // 1. Try Gemini Vision first
                            final prediction = await CarRecognitionService.instance.classify(photoPath);
                            if (prediction != null) {
                              setModalState(() {
                                brandCtrl.text    = prediction.brand;
                                modelCtrl.text    = prediction.model;
                                yearCtrl.text     = prediction.year;
                                engineCtrl.text   = prediction.engine;
                                topSpeedCtrl.text = prediction.topSpeed;
                                accelCtrl.text    = prediction.acceleration;
                                hpCtrl.text       = prediction.horsepower;
                                priceCtrl.text    = prediction.price;
                                originCtrl.text   = prediction.origin;
                                featureCtrl.text  = prediction.feature;
                                descCtrl.text     = prediction.description;
                                autoFillLoading   = false;
                              });
                              return;
                            }

                            // 2. Fallback: CSV lookup by typed brand + model
                            final rows = csvRows ??
                                const CsvToListConverter(eol: '\n').convert(
                                  await rootBundle.loadString('assets/cars.csv'));
                            final inputBrand = brandCtrl.text.trim().toLowerCase().replaceAll(' ', '');
                            final inputModel = modelCtrl.text.trim().toLowerCase();
                            if (inputBrand.isNotEmpty && inputModel.isNotEmpty) {
                              final match = rows.firstWhere(
                                (r) => r.length > 10 &&
                                  r[0].toString().toLowerCase().replaceAll(' ', '') == inputBrand &&
                                  r[1].toString().toLowerCase() == inputModel,
                                orElse: () => <dynamic>[],
                              );
                              if (match.isNotEmpty) {
                                setModalState(() {
                                  yearCtrl.text     = match[8].toString();
                                  engineCtrl.text   = match[3].toString();
                                  topSpeedCtrl.text = match[4].toString();
                                  accelCtrl.text    = match[5].toString();
                                  hpCtrl.text       = match[6].toString();
                                  priceCtrl.text    = match[7].toString();
                                  originCtrl.text   = match[9].toString();
                                  featureCtrl.text  = match[10].toString();
                                  descCtrl.text     = match[2].toString();
                                  autoFillLoading   = false;
                                });
                                return;
                              }
                            }

                            setModalState(() => autoFillLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('garage.autoFillNotFound'.tr()), duration: const Duration(seconds: 2)),
                              );
                            }
                          } catch (_) {
                            setModalState(() => autoFillLoading = false);
                          }
                        },
                  child: Builder(builder: (_) {
                    final isPremium = PremiumService.instance.isPremium;
                    final color = isPremium ? const Color(0xFFEF5350) : Colors.white38;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isPremium
                            ? const Color(0xFFEF5350).withOpacity(0.15)
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isPremium ? const Color(0xFFEF5350) : Colors.white24,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (autoFillLoading)
                            const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF5350)),
                            )
                          else if (!isPremium)
                            const Icon(Icons.lock, size: 14, color: Colors.white38)
                          else
                            const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFEF5350)),
                          const SizedBox(width: 6),
                          Text(
                            'garage.aiAutoFill'.tr(),
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                // Required
                Text('garage.brandRequired'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(controller: brandCtrl, style: style, decoration: fieldDeco('garage.brandHint'.tr())),
                const SizedBox(height: 12),
                Text('garage.modelRequired'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(controller: modelCtrl, style: style, decoration: fieldDeco('garage.modelHint'.tr())),
                // Model suggestions filtered by brand
                Builder(builder: (_) {
                  final brand = brandCtrl.text.trim().toLowerCase().replaceAll(' ', '');
                  if (brand.isEmpty || csvRows == null) return const SizedBox.shrink();
                  final suggestions = csvRows
                    .where((r) => r is List && r.length >= 2 &&
                        r[0].toString().toLowerCase().replaceAll(' ', '') == brand)
                    .map((r) => r[1].toString())
                    .toList();
                  if (suggestions.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => setModalState(() {
                            modelCtrl.text = suggestions[i];
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(suggestions[i],
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ),
                        ),
                      ),
                    ),
                  ]);
                }),
                const SizedBox(height: 20),
                Text('garage.detailsSection'.tr(), style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('library.year'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(controller: yearCtrl, style: style, decoration: fieldDeco('2024'),
                      keyboardType: TextInputType.number),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('library.engineType'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(controller: engineCtrl, style: style, decoration: fieldDeco('garage.engineTypeHint'.tr())),
                  ])),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('library.topSpeed'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(controller: topSpeedCtrl, style: style, decoration: fieldDeco('garage.topSpeedHint'.tr())),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('garage.acceleration100'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(controller: accelCtrl, style: style, decoration: fieldDeco('garage.accelerationHint'.tr())),
                  ])),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('library.horsepower'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(controller: hpCtrl, style: style, decoration: fieldDeco('garage.horsepowerHint'.tr())),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('library.priceRange'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(controller: priceCtrl, style: style, decoration: fieldDeco('80000-100000'),
                      keyboardType: TextInputType.number),
                  ])),
                ]),
                const SizedBox(height: 12),
                Text('library.origin'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(controller: originCtrl, style: style, decoration: fieldDeco('garage.originHint'.tr())),
                const SizedBox(height: 12),
                Text('library.notableFeature'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(controller: featureCtrl, style: style, decoration: fieldDeco('garage.notableFeatureHint'.tr())),
                const SizedBox(height: 12),
                Text('library.description'.tr(), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: descCtrl,
                  style: style,
                  maxLines: 3,
                  decoration: fieldDeco('garage.descriptionHint'.tr()),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF5350),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final brand = brandCtrl.text.trim();
                    final model = modelCtrl.text.trim();
                    if (brand.isEmpty || model.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('garage.brandModelRequired'.tr())),
                      );
                      return;
                    }
                    await GarageService.instance.addCar({
                      'brand':          brand,
                      'model':          model,
                      'year':           yearCtrl.text.trim(),
                      'engineType':     engineCtrl.text.trim(),
                      'topSpeed':       topSpeedCtrl.text.trim(),
                      'acceleration':   accelCtrl.text.trim(),
                      'horsepower':     hpCtrl.text.trim(),
                      'priceRange':     priceCtrl.text.trim(),
                      'origin':         originCtrl.text.trim(),
                      'notableFeature': featureCtrl.text.trim(),
                      'description':    descCtrl.text.trim(),
                      'photoPath':      photoPath,
                    });
                    try { AudioFeedback.instance.playEvent(SoundEvent.tap); } catch (_) {}
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  },
                  child: Text(
                    'garage.addToMyGarage'.tr(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_cameraReady) {
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
        title: Text('garage.scanPageTitle'.tr(), style: const TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: CameraPreview(_controller!),
          ),
          if (_scaledRects.isNotEmpty)
            CustomPaint(
              size: size,
              painter: _BoundingBoxPainter(
                scaledRects: _scaledRects,
                detectedLabel: 'garage.carDetectedLabel'.tr(),
              ),
            ),
          // Status bar
          Positioned(
            top: 16, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statusText,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ),
          ),
          // Capture button
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _capturing ? null : _onCapture,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEF5350),
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                  ),
                  child: _capturing
                      ? const Center(
                          child: SizedBox(
                            width: 28, height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  final List<Rect> scaledRects;
  final String detectedLabel;
  _BoundingBoxPainter({required this.scaledRects, required this.detectedLabel});

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..color = const Color(0xFFEF5350)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final bgPaint = Paint()
      ..color = const Color(0xFFEF5350)
      ..style = PaintingStyle.fill;

    for (final rect in scaledRects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)), boxPaint);

      final label = '  $detectedLabel  ';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final labelRect = Rect.fromLTWH(rect.left, rect.top - 24, tp.width, 22);
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)), bgPaint);
      tp.paint(canvas, Offset(rect.left, rect.top - 22));
    }
  }

  @override
  bool shouldRepaint(_BoundingBoxPainter old) => old.scaledRects != scaledRects;
}
