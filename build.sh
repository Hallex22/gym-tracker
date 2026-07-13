#!/bin/bash

# 1. Generăm un build number unic bazat pe timestamp-ul curent (secunde)
BUILD_NUMBER=$(date +%s)

echo "🚀 Pornire Build APK optimizat..."
echo "🔢 Build Number generat automat: $BUILD_NUMBER"
echo "--------------------------------------------------"

# 2. Curățăm cache-ul vechi și tragem dependințele ca să evităm erorile
flutter clean
flutter pub get

# 3. Rulăm build-ul cu split și cu build number-ul injectat dinamic
flutter build apk --split-per-abi --build-number=$BUILD_NUMBER

echo "--------------------------------------------------"
echo "✅ Build finalizat cu succes!"
echo "📂 Găsești APK-ul optimizat în: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"