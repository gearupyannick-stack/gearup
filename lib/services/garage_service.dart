// lib/services/garage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GarageService {
  GarageService._();
  static final instance = GarageService._();
  static const _key = 'garage_cars';

  Future<List<Map<String, String>>> loadGarageCars() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Map<String, String>.from(e as Map)).toList();
  }

  /// Saves a full car map (brand, model, year, engineType, etc.)
  /// If a car with the same brand+model already exists, appends #2, #3, etc.
  Future<void> addCar(Map<String, String> car) async {
    final brand = car['brand'] ?? '';
    final model = car['model'] ?? '';
    if (brand.isEmpty || model.isEmpty) return;
    final cars = await loadGarageCars();
    // Strip any existing "#n" suffix to get the base model name
    final baseModel = model.replaceAll(RegExp(r'\s*#\d+$'), '');
    final duplicates = cars.where((c) =>
      c['brand'] == brand &&
      (c['model'] ?? '').replaceAll(RegExp(r'\s*#\d+$'), '') == baseModel,
    ).length;
    final carToAdd = Map<String, String>.from(car);
    if (duplicates > 0) {
      carToAdd['model'] = '$baseModel #${duplicates + 1}';
    }
    cars.add(carToAdd);
    await _save(cars);
  }

  Future<void> removeCar(String brand, String model) async {
    final cars = await loadGarageCars();
    cars.removeWhere((c) => c['brand'] == brand && c['model'] == model);
    await _save(cars);
  }

  Future<bool> hasCar(String brand, String model) async {
    final cars = await loadGarageCars();
    return cars.any((c) => c['brand'] == brand && c['model'] == model);
  }

  /// Returns the list of local photo paths for a car.
  /// Reads from 'photoPaths' (JSON list) with fallback to legacy 'photoPath'.
  List<String> getPhotoPaths(Map<String, String> car) {
    final raw = car['photoPaths'];
    if (raw != null && raw.isNotEmpty) {
      return List<String>.from(jsonDecode(raw) as List);
    }
    final legacy = car['photoPath'];
    if (legacy != null && legacy.isNotEmpty) return [legacy];
    return [];
  }

  /// Appends [newPhotoPath] to the car's photo list and persists.
  Future<void> addPhotoToCar(String brand, String model, String newPhotoPath) async {
    final cars = await loadGarageCars();
    final idx = cars.indexWhere((c) => c['brand'] == brand && c['model'] == model);
    if (idx == -1) return;
    final car = Map<String, String>.from(cars[idx]);
    final paths = getPhotoPaths(car)..add(newPhotoPath);
    car['photoPaths'] = jsonEncode(paths);
    car['photoPath'] = paths.first; // keep primary for backward-compat
    cars[idx] = car;
    await _save(cars);
  }

  Future<void> _save(List<Map<String, String>> cars) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(cars));
  }
}
