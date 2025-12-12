import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GeminiTTSService {
  static final GeminiTTSService _instance = GeminiTTSService._internal();
  factory GeminiTTSService() => _instance;
  GeminiTTSService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentText;

  bool get isPlaying => _isPlaying;
  String? get currentText => _currentText;

  void _updatePlayingState(bool playing, [String? text]) {
    _isPlaying = playing;
    _currentText = text;
  }

  Future<void> toggleAudio(String text, String apiKey) async {
    if (_isPlaying) {
      await stop();
    } else {
      await speak(text, apiKey);
    }
  }

  Future<void> speak(String text, String apiKey) async {
    try {
      await stop();
      _updatePlayingState(true, text);
      
      if (kIsWeb) {
        // For web, show message that TTS is not available due to CORS
        _updatePlayingState(false);
        throw Exception('TTS not available in web preview. Use mobile app for full functionality.');
      }
      
      final cleanText = _cleanText(text);
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateSpeech?key=$apiKey';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'input': cleanText,
          'voice': {'voiceName': 'Charcoal'}
        }),
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final audioBase64 = responseData['audio'];
        
        if (audioBase64 != null) {
          final audioBytes = base64Decode(audioBase64);
          
          _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
            if (state == PlayerState.completed || state == PlayerState.stopped) {
              _updatePlayingState(false);
            }
          });
          
          await _audioPlayer.play(BytesSource(audioBytes));
        } else {
          throw Exception('No audio data received');
        }
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      _updatePlayingState(false);
      throw Exception('TTS failed: $e');
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _updatePlayingState(false);
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'[🏥🔍💡🌐]'), '')
        .replaceAll(RegExp(r'[:|\\-\\*\\#]'), ' ')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim()
        .substring(0, text.length > 200 ? 200 : text.length);
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}