# 📱 MedReport Analyzer - Flutter App

A Flutter mobile application that analyzes medical reports using Google Gemini AI and provides translations in Telugu/Hindi with audio support.

## ✨ Features

- 🏥 **Medical Report Analysis** - AI-powered analysis with Gemini 2.5 Flash
- 📸 **Image Processing** - Extract text from medical report images
- 📄 **PDF Support** - Analyze PDF medical documents
- 🌐 **Multi-language** - Telugu and Hindi translations
- 🔊 **Audio Output** - Text-to-speech in multiple languages
- 🔐 **User Authentication** - Sign up/sign in functionality
- 📱 **Modern UI** - Clean, responsive design for mobile and tablet

## 🚀 Quick Start

### Prerequisites
- Flutter SDK installed
- Android SDK for APK building
- Android device or emulator

### Installation
```bash
# Navigate to app directory
cd flutter_app

# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build APK
flutter build apk --release
```

### APK Location
After building: `build/app/outputs/flutter-apk/app-release.apk`

## 🏗️ Project Structure

```
flutter_app/
├── lib/
│   ├── services/
│   │   └── gemini_tts_service.dart    # TTS functionality
│   ├── widgets/
│   │   ├── action_buttons.dart        # UI components
│   │   ├── result_cards.dart          # Results display
│   │   └── user_header_card.dart      # User interface
│   ├── auth_service.dart              # Authentication
│   ├── login_screen.dart              # Login/signup
│   └── main.dart                      # App entry point
├── android/                           # Android configuration
├── web/                              # Web configuration
└── pubspec.yaml                      # Dependencies
```

## 🔧 Configuration

### API Keys
Update the Gemini API key in `lib/main.dart`:
```dart
static const String _geminiApiKey = 'YOUR_GEMINI_API_KEY';
```

### Android Setup
Ensure Android SDK is properly configured:
```bash
flutter doctor --android-licenses
```

## 📱 Usage

1. **Sign Up/Login** - Create account or sign in
2. **Select Input Method**:
   - Type medical report text
   - Upload image of medical report
   - Select PDF document
3. **Choose Language** - Telugu or Hindi
4. **Analyze** - Get AI-powered analysis
5. **Listen** - Audio playback of translation

## 🎯 Features Breakdown

### Medical Analysis
- Patient situation assessment
- Criticality level evaluation
- Possible causes identification
- Recovery advice and recommendations

### Multi-format Support
- **Text Input** - Direct text entry
- **Image Processing** - Camera/gallery photos
- **PDF Documents** - Text extraction from PDFs

### Audio Features
- Gemini TTS integration
- Telugu and Hindi voice support
- Play/stop audio controls

## 🛠️ Development

### Debug Mode
```bash
flutter run --debug
```

### Release Build
```bash
flutter build apk --release
```

### Testing
```bash
flutter test
```

## 📋 Dependencies

- `google_generative_ai` - AI analysis
- `audioplayers` - Audio playback
- `image_picker` - Image selection
- `file_picker` - PDF selection
- `syncfusion_flutter_pdf` - PDF processing
- `http` - API requests

## 🎨 UI/UX

- **Modern Design** - Card-based layout
- **Responsive** - Mobile and tablet support
- **Animations** - Smooth transitions
- **Accessibility** - User-friendly interface

## 🚀 Deployment

The app is ready for:
- Google Play Store distribution
- Direct APK installation
- Enterprise deployment

## 📄 License

This project is for medical report analysis and educational purposes.

---

**Built with Flutter 💙 | Powered by Google Gemini AI 🤖**