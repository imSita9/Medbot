import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TTSService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;

  static Future<void> _initializeTTS() async {
    if (_isInitialized) return;
    
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.6);
      await _flutterTts.setPitch(1.0);
      _isInitialized = true;
    } catch (e) {
      print('TTS initialization failed: $e');
    }
  }

  static Future<String> _optimizeTextWithGemini(String text, String language) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return text;
      }

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final prompt = '''
      Optimize this medical text for clear speech in $language.
      Make it natural and easy to understand when spoken:
      
      $text
      
      Return only the speech-optimized text in $language.
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? text;
    } catch (e) {
      print('Gemini optimization failed: $e');
      return text;
    }
  }

  static Future<bool> speak(String text, String language) async {
    try {
      await _initializeTTS();
      
      // Optimize text with Gemini 2.5 Flash
      final optimizedText = await _optimizeTextWithGemini(text, language);
      
      // Set language
      String languageCode;
      switch (language.toLowerCase()) {
        case 'telugu':
          languageCode = 'te-IN';
          break;
        case 'hindi':
          languageCode = 'hi-IN';
          break;
        default:
          languageCode = 'en-US';
      }
      
      await _flutterTts.setLanguage(languageCode);
      
      // Speak the optimized text
      final result = await _flutterTts.speak(optimizedText);
      return result == 1;
      
    } catch (e) {
      print('TTS failed: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      print('Stop TTS failed: $e');
    }
  }

  static void dispose() {
    // FlutterTts doesn't need explicit disposal
  }
}