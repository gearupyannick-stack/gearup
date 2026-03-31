// lib/pages/garage_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/garage_service.dart';
import '../services/audio_feedback.dart';
import '../widgets/car_detail_sheet.dart';
import 'garage_camera_page.dart';

class GaragePage extends StatefulWidget {
  const GaragePage({Key? key}) : super(key: key);
  @override
  _GaragePageState createState() => _GaragePageState();
}

class _GaragePageState extends State<GaragePage> {
  List<Map<String, String>> _garageCars = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    try {
      AudioFeedback.instance.playEvent(SoundEvent.pageOpen);
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadGarage();
    }
  }

  Future<void> _loadGarage() async {
    final saved = await GarageService.instance.loadGarageCars();
    if (mounted) setState(() => _garageCars = saved);
  }

  Future<void> _openCamera() async {
    try {
      AudioFeedback.instance.playEvent(SoundEvent.tap);
    } catch (_) {}
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GarageCameraPage(allCars: _garageCars),
      ),
    );
    await _loadGarage();
  }

  Future<void> _confirmDelete(Map<String, String> car) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text('garage.removeTitle'.tr(),
            style: const TextStyle(color: Colors.white)),
        content: Text(
          '${car['brand']} ${car['model']}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('garage.remove'.tr(),
                style: const TextStyle(color: Color(0xFFEF5350))),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await GarageService.instance
          .removeCar(car['brand']!, car['model']!);
      await _loadGarage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'garage.title'.tr(),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo,
                color: Color(0xFFEF9A9A)),
            onPressed: _openCamera,
            tooltip: 'garage.scanTooltip'.tr(),
          ),
        ],
      ),
      body: _garageCars.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.garage_outlined,
                      size: 72,
                      color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    'garage.empty'.tr(),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'garage.tapToScan'.tr(),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 14),
                  ),
                ],
              ),
            )
          : GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: _garageCars.map((car) {
                final brand = car['brand'] ?? '';
                final model = car['model'] ?? '';
                final fileBase =
                    CarDetailSheet.formatFileName(brand, model);
                final fileName = '${fileBase}4.webp';
                return GestureDetector(
                  onTap: () {
                    try {
                      AudioFeedback.instance.playEvent(SoundEvent.tap);
                    } catch (_) {}
                    CarDetailSheet.show(
                      context,
                      car,
                      showGarageToggle: true,
                      onGarageToggled: () async {
                        await _loadGarage();
                      },
                    );
                  },
                  onLongPress: () => _confirmDelete(car),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        car['photoPath']?.isNotEmpty == true
                            ? Image.file(
                                File(car['photoPath']!),
                                fit: BoxFit.cover,
                              )
                            : Image.asset(
                                'assets/model/$fileName',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[900],
                                  child: const Icon(Icons.directions_car, color: Colors.white54, size: 36),
                                ),
                              ),
                        Container(
                          color: Colors.black26,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                brand,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                model,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
