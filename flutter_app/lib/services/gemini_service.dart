import 'dart:async';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(seconds: 2);
  static const Duration _timeout = Duration(seconds: 30);
  
  static GenerativeModel? _model;
  
  static GenerativeModel get model {
    if (_model == null) {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Gemini API key not found in environment');
      }
      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );
    }
    return _model!;
  }
  
  static Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }
  
  static Future<String> analyzeWithRetry({
    required List<Content> content,
    int retryCount = 0,
  }) async {
    // Check internet connectivity first
    if (!await _checkConnectivity()) {
      throw NetworkException('No internet connection available');
    }
    
    try {
      final response = await model
          .generateContent(content)
          .timeout(_timeout);
      
      return response.text ?? 'No response received';
      
    } on SocketException catch (e) {
      if (retryCount < _maxRetries) {
        final delay = _baseDelay * (retryCount + 1);
        await Future.delayed(delay);
        return analyzeWithRetry(content: content, retryCount: retryCount + 1);
      }
      throw NetworkException('Network connection failed: ${e.message}');
      
    } on TimeoutException catch (_) {
      if (retryCount < _maxRetries) {
        final delay = _baseDelay * (retryCount + 1);
        await Future.delayed(delay);
        return analyzeWithRetry(content: content, retryCount: retryCount + 1);
      }
      throw NetworkException('Request timeout - please check your connection');
      
    } on GenerativeAIException catch (e) {
      throw ApiException('Gemini API error: ${e.message}');
      
    } catch (e) {
      if (retryCount < _maxRetries) {
        final delay = _baseDelay * (retryCount + 1);
        await Future.delayed(delay);
        return analyzeWithRetry(content: content, retryCount: retryCount + 1);
      }
      throw UnknownException('Unexpected error: ${e.toString()}');
    }
  }
}

// Custom exception classes
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class UnknownException implements Exception {
  final String message;
  UnknownException(this.message);
  @override
  String toString() => message;
}