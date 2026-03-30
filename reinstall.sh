#!/bin/bash

# Package name / Bundle ID
PACKAGE_NAME="com.gearup.app"

# Find the nearest Flutter project
if [ -f "pubspec.yaml" ]; then
    PROJECT_DIR="."
elif [ -d "gearup_android" ] && [ -f "gearup_android/pubspec.yaml" ]; then
    PROJECT_DIR="gearup_android"
elif [ -d "gearup_ios" ] && [ -f "gearup_ios/pubspec.yaml" ]; then
    PROJECT_DIR="gearup_ios"
else
    echo "❌ Error: Could not find a Flutter project directory (no pubspec.yaml)."
    exit 1
fi

echo "🚀 Starting Reinstall Process for $PACKAGE_NAME in $PROJECT_DIR..."

# 1. Try to uninstall from Android
if command -v adb &> /dev/null; then
    echo "📱 Checking for Android devices..."
    if adb get-state &> /dev/null; then
        echo "🗑️  Uninstalling from Android..."
        adb uninstall $PACKAGE_NAME
    else
        echo "⏩ No Android device connected, skipping."
    fi
else
    echo "⏩ ADB not found, skipping Android uninstall."
fi

# 2. Try to uninstall from iOS Simulator
if command -v xcrun &> /dev/null; then
    echo "🍎 Checking for iOS Simulator..."
    if xcrun simctl list | grep -q "Booted"; then
        echo "🗑️  Uninstalling from iOS Simulator..."
        xcrun simctl uninstall booted $PACKAGE_NAME
    else
        echo "⏩ No iOS Simulator booted, skipping."
    fi
else
    echo "⏩ xcrun not found, skipping iOS uninstall."
fi

# 3. Clean and Rebuild in the project directory
cd "$PROJECT_DIR" || exit
echo "🧹 Cleaning Flutter build..."
flutter clean

echo "📦 Fetching dependencies..."
flutter pub get

echo "🏗️  Running App..."
flutter run
