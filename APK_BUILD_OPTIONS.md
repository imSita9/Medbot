# 📱 APK Build Options

## 🎯 Option 1: Local Build (Recommended)

### Prerequisites:
```bash
# Install Android SDK
sudo apt update
sudo apt install android-sdk
export ANDROID_HOME=/usr/lib/android-sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools

# Accept licenses
flutter doctor --android-licenses
```

### Build Commands:
```bash
cd flutter_app

# Debug APK (for testing)
flutter build apk --debug

# Release APK (for distribution)
flutter build apk --release

# Split APKs by architecture (smaller size)
flutter build apk --split-per-abi

# APK location: build/app/outputs/flutter-apk/
```

## 🎯 Option 2: Online Build Services

### A) GitHub Actions (Free)
1. Push code to GitHub
2. Create `.github/workflows/build.yml`:
```yaml
name: Build APK
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - uses: actions/setup-java@v1
      with:
        java-version: '12.x'
    - uses: subosito/flutter-action@v1
    - run: flutter pub get
    - run: flutter build apk --release
    - uses: actions/upload-artifact@v2
      with:
        name: apk
        path: build/app/outputs/flutter-apk/app-release.apk
```

### B) Codemagic (Free tier)
1. Go to codemagic.io
2. Connect GitHub repository
3. Configure build settings
4. Download APK

### C) AppCenter (Microsoft)
1. Upload to appcenter.ms
2. Configure build pipeline
3. Automatic APK generation

## 🎯 Option 3: Docker Build

```bash
# Create Dockerfile for Flutter
FROM cirrusci/flutter:stable

WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build apk --release

# Run container
docker build -t medreport-builder .
docker run -v $(pwd)/build:/app/build medreport-builder
```

## 🎯 Option 4: Cloud Build

### Google Cloud Build:
```yaml
# cloudbuild.yaml
steps:
- name: 'cirrusci/flutter:stable'
  entrypoint: 'flutter'
  args: ['pub', 'get']
- name: 'cirrusci/flutter:stable'
  entrypoint: 'flutter'
  args: ['build', 'apk', '--release']
```

## 🎯 Option 5: Android Studio

1. Open `flutter_app/android` in Android Studio
2. Build → Generate Signed Bundle/APK
3. Choose APK
4. Create keystore or use existing
5. Build release APK

## 🎯 Option 6: Gradle Direct Build

```bash
cd flutter_app/android
./gradlew assembleRelease

# APK location: app/build/outputs/apk/release/
```

## 🚀 Quick Start (Easiest)

```bash
# 1. Navigate to Flutter app
cd /home/chandu/Desktop/MedReport-Bot-Clean/flutter_app

# 2. Get dependencies
flutter pub get

# 3. Build APK
flutter build apk --release

# 4. Find APK at:
# build/app/outputs/flutter-apk/app-release.apk
```

## 📋 APK Types

- **Debug APK**: `flutter build apk --debug` (larger, for testing)
- **Release APK**: `flutter build apk --release` (optimized, for distribution)
- **Split APKs**: `flutter build apk --split-per-abi` (separate APKs per architecture)

## 🔧 Troubleshooting

If build fails:
```bash
# Clean and retry
flutter clean
flutter pub get
flutter build apk --release

# Check Flutter setup
flutter doctor

# Fix Android licenses
flutter doctor --android-licenses
```

Choose **Option 1 (Local Build)** for fastest results! 🎉