// lib/services/car_recognition_service.dart
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';

class CarPrediction {
  final String brand;
  final String model;
  final String year;
  final String engine;
  final String topSpeed;
  final String acceleration;
  final String horsepower;
  final String price;
  final String origin;
  final String feature;
  final String description;

  const CarPrediction({
    required this.brand,
    required this.model,
    this.year = '',
    this.engine = '',
    this.topSpeed = '',
    this.acceleration = '',
    this.horsepower = '',
    this.price = '',
    this.origin = '',
    this.feature = '',
    this.description = '',
  });

  bool get hasSpecs => year.isNotEmpty || engine.isNotEmpty || horsepower.isNotEmpty;
  bool get hasModel => model.isNotEmpty;
}

/// Sends the captured photo to Gemini Flash to identify the car and fill all specs.
/// Free tier: 1,500 requests/day, 15/min — no billing required.
class CarRecognitionService {
  CarRecognitionService._();
  static final instance = CarRecognitionService._();

  static const _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyBlM1EChVyOBIsP--kEF6nQfzmBpjyR2sU',
  );

  static const _prompt =
      'Look at this photo. If there is a car visible, identify it and provide its specifications.\n'
      'Reply ONLY in this exact format with no extra text:\n'
      'Brand: <brand name>\n'
      'Model: <model name>\n'
      'Year: <manufacturing year, e.g. 2023>\n'
      'Engine: <engine type, e.g. V8, Electric, V6 Turbo>\n'
      'Top Speed: <top speed in km/h, number only, e.g. 250>\n'
      'Acceleration: <0-100 km/h time in seconds, e.g. 4.2 seconds>\n'
      'Horsepower: <power in HP, number only, e.g. 450 HP>\n'
      'Price: <approximate price range in USD, e.g. 50000-70000>\n'
      'Origin: <country of manufacture, e.g. Made in Germany>\n'
      'Feature: <one distinctive feature or technology>\n'
      'Description: <one sentence description of this car>\n\n'
      'If you cannot identify the car or there is no car, reply exactly:\n'
      'Brand: unknown\n'
      'Model: unknown';

  Future<CarPrediction?> classify(String imagePath) async {
    if (_apiKey.isEmpty) {
      print('[CarRecognition] No GEMINI_API_KEY configured');
      return null;
    }
    try {
      final genModel = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
      );

      final imageBytes = await File(imagePath).readAsBytes();
      final response = await genModel.generateContent([
        Content.multi([
          TextPart(_prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ]);

      final text = response.text?.trim() ?? '';
      print('[CarRecognition] Gemini response: $text');

      String field(String key) {
        final match = RegExp(
          '$key:\\s*(.+)',
          caseSensitive: false,
        ).firstMatch(text);
        final val = match?.group(1)?.trim() ?? '';
        return val.toLowerCase() == 'unknown' ? '' : val;
      }

      final brand = field('Brand');
      if (brand.isEmpty) return null;

      return CarPrediction(
        brand: brand,
        model: field('Model'),
        year: field('Year'),
        engine: field('Engine'),
        topSpeed: field('Top Speed'),
        acceleration: field('Acceleration'),
        horsepower: field('Horsepower'),
        price: field('Price'),
        origin: field('Origin'),
        feature: field('Feature'),
        description: field('Description'),
      );
    } catch (e) {
      print('[CarRecognition] ERROR: $e');
      return null;
    }
  }
}
