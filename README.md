# GearUp 🚗📱

GearUp is a Flutter mobile app designed to help users learn about cars — brands, models, years, origins, and technical specs — in a gamified and engaging way. Think of it as **Duolingo for cars**: quizzes, challenges, and achievements make learning fun while ads and premium features support the project.

---

## Features

- **Training mode**: 20-question multiple-choice quizzes on categories like brand, model, year, origin, engine type, speed, and more.
- **Home challenges**: Quick car logo and flag challenges to test recognition.
- **Library**: Browse cars by brand and explore specifications.
- **My Garage**: Add your own cars by taking a photo — AI auto-fill (Gemini Vision) instantly recognises the car and fills in all specs (premium feature).
- **Profile**: Track progress, unlock achievements, and manage your account.
- **Gamification**: Points, lives, achievements, and streaks to keep users motivated.
- **Ads integration**: Google Mobile Ads for free users, interstitials shown at intervals.
- **Premium plan**: Unlimited lives, no ads, unlimited training, and AI car recognition.

---

## Tech Stack

- [Flutter](https://flutter.dev/) 3.35 (Dart 3.9)
- Firebase (Auth, Analytics, Firestore)
- Google Mobile Ads SDK
- SharedPreferences for local achievements
- Play Asset Delivery for images
- GitHub Actions CI/CD for Android and iOS builds

---

## Project Structure

```plaintext
lib/
 ├── main.dart                   # App entry point
 ├── firebase_options.dart        # Firebase setup
 ├── pages/
 │    ├── home_page.dart
 │    ├── training_page.dart
 │    ├── library_page.dart
 │    ├── profile_page.dart
 │    ├── welcome_page.dart
 │    └── challenges/
 │         ├── brand_challenge_page.dart
 │         ├── model_challenge_page.dart
 │         ├── acceleration_challenge_page.dart
 │         ├── power_challenge_page.dart
 │         ├── origin_challenge_page.dart
 │         ├── engine_type_challenge_page.dart
 │         ├── models_by_brand_challenge_page.dart
 │         ├── max_speed_challenge_page.dart
 │         └── special_feature_challenge_page.dart
 ├── services/
 │    ├── ad_manager.dart
 │    ├── image_service_cache.dart
 │    └── lives_storage.dart

```
---

## Getting Started

### Prerequisites
- Flutter SDK (>=3.35)
- Dart (>=3.9)
- Android Studio or Xcode for emulator builds
- Firebase project set up with `google-services.json` and `GoogleService-Info.plist`

### Installation
```bash
# Clone the repository
git clone https://github.com/gearupyannick-stack/gearup.git
cd gearup
```


## Support

If you have any issues, questions, or feedback, please contact:

**Email:** gearup.yannick@gmail.com 

Or open an issue in this repository.

# Privacy Policy for GearUp

GearUp does not collect personal information from users.  
The app uses Google AdMob to serve ads, which may collect anonymous usage data.  
Please refer to Google’s AdMob privacy policy for more details: https://policies.google.com/privacy  

For support or questions: gearup.yannick@gmail.com


## About

- **App Name:** GearUp  
- **Developer:** Yannick Durindel  
- **Platform:** iOS & Android  
- **Category:** Education / Trivia  

© 2025 Yannick Durindel. All rights reserved.
