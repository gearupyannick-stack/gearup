// lib/widgets/car_detail_sheet.dart
// Extracted from LibraryPage._showModelDetails. Provides a reusable
// car detail dialog with photo carousel and optional garage toggle.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../services/audio_feedback.dart';
import '../services/garage_service.dart';
import '../pages/garage_photo_capture_page.dart';

class CarDetailSheet {
  CarDetailSheet._();

  /// Converts "brand" + "model" to the normalised file-name prefix used in
  /// assets/model (e.g. "Ferrari" + "488 GTB" -> "Ferrari488Gtb").
  static String formatFileName(String brand, String model) {
    final raw = (brand + model).replaceAll(RegExp(r'[ ./]'), '');
    return raw
        .split(RegExp(r'(?=[A-Z])|(?<=[a-z])(?=[A-Z])|(?<=[a-z])(?=[0-9])'))
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join();
  }

  /// Shows the car detail dialog.
  ///
  /// When [showGarageToggle] is true a button lets the user add/remove the car
  /// from their garage. [onGarageToggled] is called after each toggle so that
  /// the parent page can refresh its state.
  static void show(
    BuildContext context,
    Map<String, String> car, {
    bool showGarageToggle = false,
    VoidCallback? onGarageToggled,
  }) {
    final brand = car['brand'] ?? '';
    final modelName = car['model'] ?? '';
    final fileBase = formatFileName(brand, modelName);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CarDetailDialog(
        car: car,
        brand: brand,
        modelName: modelName,
        fileBase: fileBase,
        showGarageToggle: showGarageToggle,
        onGarageToggled: onGarageToggled,
      ),
    );
  }

  static void _showFullScreenImage(
      BuildContext context, String fileBase, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _FullScreenImageViewer(
          fileBase: fileBase,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal dialog widget – keeps the garage button reactive via setState.
// ---------------------------------------------------------------------------

class _CarDetailDialog extends StatefulWidget {
  final Map<String, String> car;
  final String brand;
  final String modelName;
  final String fileBase;
  final bool showGarageToggle;
  final VoidCallback? onGarageToggled;

  const _CarDetailDialog({
    required this.car,
    required this.brand,
    required this.modelName,
    required this.fileBase,
    required this.showGarageToggle,
    this.onGarageToggled,
  });

  @override
  State<_CarDetailDialog> createState() => _CarDetailDialogState();
}

class _CarDetailDialogState extends State<_CarDetailDialog> {
  bool _inGarage = false;
  List<String> _localPhotoPaths = [];

  @override
  void initState() {
    super.initState();
    if (widget.showGarageToggle) {
      _checkGarage();
      _loadLocalPhotos();
    }
  }

  Future<void> _checkGarage() async {
    final has = await GarageService.instance.hasCar(widget.brand, widget.modelName);
    if (mounted) setState(() => _inGarage = has);
  }

  Future<void> _loadLocalPhotos() async {
    final cars = await GarageService.instance.loadGarageCars();
    final car = cars.firstWhere(
      (c) => c['brand'] == widget.brand && c['model'] == widget.modelName,
      orElse: () => widget.car,
    );
    final paths = GarageService.instance.getPhotoPaths(car);
    if (mounted) setState(() => _localPhotoPaths = paths);
  }

  Future<void> _toggleGarage() async {
    try {
      AudioFeedback.instance.playEvent(SoundEvent.tap);
    } catch (_) {}
    if (_inGarage) {
      await GarageService.instance.removeCar(widget.brand, widget.modelName);
    } else {
      await GarageService.instance.addCar({'brand': widget.brand, 'model': widget.modelName});
    }
    if (mounted) setState(() => _inGarage = !_inGarage);
    widget.onGarageToggled?.call();
  }

  Future<void> _addPhoto() async {
    try {
      AudioFeedback.instance.playEvent(SoundEvent.tap);
    } catch (_) {}
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const GaragePhotoCapturePage()),
    );
    if (path == null || !mounted) return;
    await GarageService.instance.addPhotoToCar(widget.brand, widget.modelName, path);
    await _loadLocalPhotos();
    widget.onGarageToggled?.call();
  }

  void _showFullScreenLocalPhoto(String path) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hero Image Header
              Stack(
                children: [
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: widget.car['photoPath']?.isNotEmpty == true
                        ? Image.file(
                            File(widget.car['photoPath']!),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Image.asset(
                            'assets/model/${widget.fileBase}0.webp',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[900],
                              child: const Icon(Icons.directions_car, color: Colors.white54, size: 40),
                            ),
                          ),
                  ),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 56,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.brand,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.modelName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        try {
                          AudioFeedback.instance.playEvent(SoundEvent.tap);
                        } catch (_) {}
                        Navigator.of(context).pop();
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Garage toggle button
                      if (widget.showGarageToggle) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _toggleGarage,
                            icon: Icon(
                              _inGarage
                                  ? Icons.garage
                                  : Icons.garage_outlined,
                              color: const Color(0xFFEF9A9A),
                            ),
                            label: Text(
                              _inGarage
                                  ? 'garage.inGarage'.tr()
                                  : 'garage.addToGarageBtn'.tr(),
                              style: const TextStyle(
                                  color: Color(0xFFEF9A9A)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xFFEF9A9A)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Description
                      if (widget.car['description']?.isNotEmpty ?? false) ...[
                        Text(
                          widget.car['description']!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // My Photos section — shown when viewing from garage
                      if (widget.showGarageToggle) ...[
                        Text(
                          'garage.myPhotos'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 110,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              // Existing photos
                              ..._localPhotoPaths.map((path) => GestureDetector(
                                onTap: () => _showFullScreenLocalPhoto(path),
                                child: Container(
                                  width: 110,
                                  margin: const EdgeInsets.only(right: 10),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(File(path), fit: BoxFit.cover),
                                  ),
                                ),
                              )),
                              // Add photo tile
                              GestureDetector(
                                onTap: _addPhoto,
                                child: Container(
                                  width: 80,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2A2A),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo_outlined,
                                        color: Color(0xFFEF9A9A),
                                        size: 28,
                                      ),
                                      SizedBox(height: 6),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Specifications Title
                      Text(
                        'library.specifications'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Specs
                      _buildSpecCard(Icons.settings, 'library.engineType'.tr(),
                          widget.car['engineType'] ?? ''),
                      const SizedBox(height: 12),
                      _buildSpecCard(Icons.speed, 'library.topSpeed'.tr(),
                          widget.car['topSpeed'] ?? ''),
                      const SizedBox(height: 12),
                      _buildSpecCard(Icons.rocket_launch, 'library.acceleration'.tr(),
                          widget.car['acceleration'] ?? ''),
                      const SizedBox(height: 12),
                      _buildSpecCard(Icons.flash_on, 'library.horsepower'.tr(),
                          widget.car['horsepower'] ?? ''),
                      const SizedBox(height: 12),
                      _buildSpecCard(Icons.attach_money, 'library.priceRange'.tr(),
                          widget.car['priceRange'] ?? ''),
                      const SizedBox(height: 12),
                      _buildSpecCard(Icons.calendar_today, 'library.year'.tr(),
                          widget.car['year'] ?? ''),
                      const SizedBox(height: 12),
                      _buildSpecCard(
                          Icons.flag, 'library.origin'.tr(), widget.car['origin'] ?? ''),
                      const SizedBox(height: 12),
                      _buildSpecCard(Icons.star, 'library.notableFeature'.tr(),
                          widget.car['notableFeature'] ?? ''),

                      const SizedBox(height: 24),

                      // Photo Gallery
                      Text(
                        'library.photos'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPhotoCarousel(widget.fileBase, context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white70, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCarousel(String fileBase, BuildContext context) {
    int currentIndex = 0;

    return StatefulBuilder(
      builder: (BuildContext ctx, StateSetter setCarouselState) {
        return Column(
          children: [
            CarouselSlider.builder(
              itemCount: 6,
              options: CarouselOptions(
                height: 200,
                viewportFraction: 0.85,
                enlargeCenterPage: true,
                enableInfiniteScroll: false,
                onPageChanged: (index, reason) {
                  setCarouselState(() {
                    currentIndex = index;
                  });
                },
              ),
              itemBuilder: (ctx2, index, realIndex) {
                final imageFileName = '$fileBase$index.webp';
                return GestureDetector(
                  onTap: () {
                    try {
                      AudioFeedback.instance.playEvent(SoundEvent.tap);
                    } catch (_) {}
                    CarDetailSheet._showFullScreenImage(ctx2, fileBase, index);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: Image.asset(
                        'assets/model/$imageFileName',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.directions_car, color: Colors.white54, size: 32),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return Container(
                  width: currentIndex == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: currentIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen image viewer (shared between LibraryPage and CarDetailSheet)
// ---------------------------------------------------------------------------

class _FullScreenImageViewer extends StatefulWidget {
  final String fileBase;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.fileBase,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late int currentIndex;
  final CarouselSliderController _controller = CarouselSliderController();

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: CarouselSlider.builder(
              carouselController: _controller,
              itemCount: 6,
              options: CarouselOptions(
                height: MediaQuery.of(context).size.height,
                viewportFraction: 1.0,
                enlargeCenterPage: false,
                enableInfiniteScroll: false,
                initialPage: widget.initialIndex,
                onPageChanged: (index, reason) {
                  setState(() {
                    currentIndex = index;
                  });
                },
              ),
              itemBuilder: (ctx, index, realIndex) {
                final imageFileName = '${widget.fileBase}$index.webp';
                return InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.asset(
                      'assets/model/$imageFileName',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, color: Colors.white54, size: 60),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () {
                try {
                  AudioFeedback.instance.playEvent(SoundEvent.tap);
                } catch (_) {}
                Navigator.of(context).pop();
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                return GestureDetector(
                  onTap: () => _controller.animateToPage(index),
                  child: Container(
                    width: currentIndex == index ? 32 : 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  ),
                );
              }),
            ),
          ),
          Positioned(
            bottom: 70,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '${currentIndex + 1} / 6',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
