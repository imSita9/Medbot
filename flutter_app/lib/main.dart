import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'auth_service.dart';
import 'login_screen.dart';
import 'services/gemini_service.dart';
import 'services/tts_service.dart';
import 'screens/medical_report_screen.dart';
import 'widgets/modern_input_card.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MedReportApp());
}

class MedReportApp extends StatelessWidget {
  const MedReportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedReport Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: FutureBuilder<bool>(
        future: AuthService.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data == true ? const MedicalReportScreen() : const LoginScreen();
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  String _result = '';
  bool _isLoading = false;
  String _selectedLanguage = 'English';
  File? _selectedPdf;
  Uint8List? _imageBytes;
  String? _userName;
  String? _userEmail;
  
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;
  bool _isTTSInitialized = false;
  String? _audioFilePath;
  bool _isGeneratingAudio = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _initializeTTS();
  }
  
  Future<void> _initializeTTS() async {
    if (_isTTSInitialized) return;
    
    try {
      // Set up TTS handlers first
      _flutterTts.setStartHandler(() {
        print('TTS Started');
        if (mounted) {
          setState(() => _isPlayingAudio = true);
          _showMessage('🔊 Audio playing...', Colors.green);
        }
      });
      
      _flutterTts.setCompletionHandler(() {
        print('TTS Completed');
        if (mounted) {
          setState(() => _isPlayingAudio = false);
          _showMessage('✅ Audio completed', Colors.blue);
        }
      });
      
      _flutterTts.setProgressHandler((String text, int startOffset, int endOffset, String word) {
        // Optional: Show progress
        print('TTS Progress: $word');
      });
      
      _flutterTts.setErrorHandler((msg) {
        print('TTS Error: $msg');
        if (mounted) {
          setState(() => _isPlayingAudio = false);
          _showMessage('❌ Audio error: $msg', Colors.red);
        }
      });
      
      _flutterTts.setCancelHandler(() {
        print('TTS Cancelled');
        if (mounted) {
          setState(() => _isPlayingAudio = false);
          _showMessage('⏹️ Audio stopped', Colors.orange);
        }
      });
      
      // Set basic configuration
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setLanguage('en-US');
      
      _isTTSInitialized = true;
      print('✅ TTS initialized successfully');
      
    } catch (e) {
      print('❌ TTS initialization failed: $e');
      _showMessage('TTS initialization failed', Colors.red);
    }
  }

  Future<void> _loadUserInfo() async {
    final name = await AuthService.getUserName();
    final email = await AuthService.getUserEmail();
    setState(() {
      _userName = name;
      _userEmail = email;
    });
  }

  Future<void> _analyzeReport() async {
    final inputText = _controller.text.trim();
    
    if (inputText.isEmpty && _imageBytes == null && _selectedPdf == null) {
      _showMessage('Please enter text, select image, or choose PDF', Colors.orange);
      return;
    }
    
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final content = <Content>[];
      
      if (_imageBytes != null) {
        String imagePrompt = _buildImageAnalysisPrompt();
        content.add(Content.multi([
          TextPart(imagePrompt),
          DataPart('image/jpeg', _imageBytes!)
        ]));
      } else if (_selectedPdf != null) {
        final pdfText = await _extractPdfText(_selectedPdf!);
        content.add(Content.text(_buildAnalysisPrompt(pdfText)));
      } else if (inputText.isNotEmpty) {
        content.add(Content.text(_buildAnalysisPrompt(inputText)));
      }

      final result = await GeminiService.analyzeWithRetry(content: content);
      
      setState(() {
        _result = result;
      });
      
      // Generate audio file immediately after analysis
      _generateAudioFile(result);
      
      _showMessage('Analysis completed! Audio ready.', Colors.green);
      
    } on NetworkException catch (e) {
      _showMessage('Network Error: $e', Colors.red);
    } on ApiException catch (e) {
      _showMessage('API Error: $e', Colors.red);
    } catch (e) {
      _showMessage('Error: Please check your internet connection and try again', Colors.red);
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _buildImageAnalysisPrompt() {
    return '''
    You are an experienced medical assistant and nutritionist. Analyze the attached medical report image and provide a concise summary in $_selectedLanguage.

    Your response must be in plain text only. Do not use emojis, asterisks, hashtags, or any special formatting symbols. Use the following structure exactly:

    Condition: briefly identify the primary diagnosis or finding
    Urgency: specify if this is Low, Medium, High, or Critical

    Foods to Eat: list beneficial foods that aid recovery
    Foods to Avoid: list foods that may worsen the condition

    Action: list the key medical recommendations

    Keep the entire response under 300 words to ensure it is easy to listen to.
    ''';
  }

  String _buildAnalysisPrompt(String reportText) {
    return '''
    You are an experienced medical assistant and nutritionist. Analyze the medical report text and provide a concise summary in $_selectedLanguage.

    Medical Report Text: $reportText

    Your response must be in plain text only. Do not use emojis, asterisks, hashtags, or any special formatting symbols. Use the following structure exactly:

    Condition: briefly identify the primary diagnosis or finding
    Urgency: specify if this is Low, Medium, High, or Critical

    Foods to Eat: list beneficial foods that aid recovery
    Foods to Avoid: list foods that may worsen the condition

    Action: list the key medical recommendations

    Keep the entire response under 300 words to ensure it is easy to listen to.
    ''';
  }
  

  
  Future<String> _extractPdfText(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      throw Exception('Failed to extract PDF text: $e');
    }
  }
  
  Future<void> _pickImage() async {
    try {
      // Show dialog to choose camera or gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      
      if (source != null) {
        final XFile? image = await _picker.pickImage(
          source: source,
          imageQuality: 90,
          maxWidth: 1920,
          maxHeight: 1080,
        );
        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            _imageBytes = bytes;
            _selectedPdf = null;
            _controller.clear();
          });
          _showMessage('Medical report image selected successfully!', Colors.green);
        }
      }
    } catch (e) {
      _showMessage('Image selection failed: ${e.toString()}', Colors.red);
    }
  }
  
  Future<void> _pickPdf() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          if (!kIsWeb && file.path != null) {
            _selectedPdf = File(file.path!);
          }
          _imageBytes = null;
          _controller.clear();
        });
        _showMessage('PDF selected successfully!', Colors.green);
      }
    } catch (e) {
      _showMessage('PDF selection failed: $e', Colors.red);
    }
  }
  
  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  void _clearAll() {
    setState(() {
      _controller.clear();
      _selectedPdf = null;
      _imageBytes = null;
      _result = '';
    });
    _showMessage('All data cleared', Colors.grey);
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _speak(String text) async {
    // Ensure TTS is initialized
    if (!_isTTSInitialized) {
      await _initializeTTS();
    }
    
    // Handle stop/start logic
    if (_isPlayingAudio) {
      print('📴 Stopping TTS...');
      await _flutterTts.stop();
      setState(() => _isPlayingAudio = false);
      _showMessage('⏹️ Audio stopped by user', Colors.orange);
      return;
    }
    
    // Validate input
    if (text.trim().isEmpty) {
      _showMessage('⚠️ No text to speak', Colors.orange);
      return;
    }
    
    try {
      // Show preparation message
      _showMessage('🤖 Preparing Gemini-optimized speech...', Colors.blue);
      
      // Optimize text with Gemini 2.5 Flash
      String optimizedText = await _optimizeTextWithGemini(text);
      
      // Configure TTS for selected language
      await _configureTTSLanguage();
      
      // Start speaking
      print('🗣️ Starting TTS with text length: ${optimizedText.length}');
      
      final result = await _flutterTts.speak(optimizedText);
      
      if (result != 1) {
        throw Exception('TTS failed to start (result code: $result)');
      }
      
      // Set safety timeout (2 minutes max)
      _setSafetyTimeout();
      
    } catch (e) {
      print('❌ TTS Error: $e');
      setState(() => _isPlayingAudio = false);
      _showMessage('❌ Speech failed: ${e.toString()}', Colors.red);
    }
  }
  
  Future<String> _optimizeTextWithGemini(String text) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return _truncateText(text);
      }
      
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );
      
      final prompt = '''
      Convert this medical analysis to natural, clear speech in $_selectedLanguage.
      Make it easy to understand when spoken aloud:
      
      $text
      
      Requirements:
      - Use simple, clear language
      - Add natural pauses with punctuation
      - Keep medical accuracy
      - No emojis or special symbols
      - Maximum 300 words
      - Return only the speech-ready text in $_selectedLanguage
      ''';
      
      final response = await model.generateContent([Content.text(prompt)]);
      String optimizedText = response.text ?? text;
      
      return _truncateText(optimizedText);
      
    } catch (e) {
      print('⚠️ Gemini optimization failed: $e');
      return _truncateText(text);
    }
  }
  
  String _truncateText(String text) {
    // Limit text length for better TTS performance
    if (text.length > 800) {
      return text.substring(0, 800) + '... Audio truncated for performance.';
    }
    return text;
  }
  
  Future<void> _configureTTSLanguage() async {
    try {
      String languageCode;
      
      switch (_selectedLanguage.toLowerCase()) {
        case 'telugu':
          languageCode = 'te-IN';
          break;
        case 'hindi':
          languageCode = 'hi-IN';
          break;
        case 'english':
        default:
          languageCode = 'en-US';
      }
      
      await _flutterTts.setLanguage(languageCode);
      await _flutterTts.setSpeechRate(0.6); // Slightly faster for better flow
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      print('🌍 Language set to: $languageCode');
      
    } catch (e) {
      print('⚠️ Language setting failed, using English: $e');
      await _flutterTts.setLanguage('en-US');
    }
  }
  
  void _setSafetyTimeout() {
    Future.delayed(const Duration(minutes: 2), () {
      if (_isPlayingAudio && mounted) {
        print('⏰ Safety timeout reached, stopping TTS');
        _flutterTts.stop();
        setState(() => _isPlayingAudio = false);
        _showMessage('⏰ Audio timeout (2 min limit)', Colors.orange);
      }
    });
  }
  
  Future<void> _generateAudioFile(String text) async {
    if (_isGeneratingAudio) return;
    
    setState(() => _isGeneratingAudio = true);
    
    try {
      print('🎵 Starting audio generation...');
      
      // Optimize text with Gemini 2.5 Flash for audio
      String optimizedText = await _optimizeTextWithGemini(text);
      print('📝 Optimized text length: ${optimizedText.length}');
      
      // Ensure TTS is initialized
      if (!_isTTSInitialized) {
        await _initializeTTS();
      }
      
      // Configure TTS for file generation
      await _configureTTSLanguage();
      
      // Generate unique filename with WAV extension (more compatible)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'medical_analysis_$timestamp.wav';
      
      // Get app directory for saving audio
      final directory = await getApplicationDocumentsDirectory();
      final audioPath = '${directory.path}/$fileName';
      
      print('📁 Audio path: $audioPath');
      
      // Try to generate audio file
      try {
        final result = await _flutterTts.synthesizeToFile(optimizedText, audioPath);
        print('🔊 TTS synthesizeToFile result: $result');
        
        // Wait a moment for file to be written
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Verify file exists and has content
        final file = File(audioPath);
        if (await file.exists()) {
          final fileSize = await file.length();
          print('✅ Audio file created successfully. Size: $fileSize bytes');
          
          if (fileSize > 0) {
            setState(() {
              _audioFilePath = audioPath;
              _isGeneratingAudio = false;
            });
            _showMessage('🎧 Audio file ready!', Colors.green);
          } else {
            throw Exception('Audio file is empty');
          }
        } else {
          throw Exception('Audio file was not created');
        }
        
      } catch (ttsError) {
        print('❌ TTS synthesizeToFile failed: $ttsError');
        
        // Fallback: Create a simple text file as placeholder
        // and use live TTS instead
        final file = File(audioPath.replaceAll('.wav', '.txt'));
        await file.writeAsString(optimizedText);
        
        setState(() {
          _audioFilePath = 'LIVE_TTS'; // Special marker for live TTS
          _isGeneratingAudio = false;
        });
        
        _showMessage('🎤 Audio ready (live TTS mode)', Colors.blue);
      }
      
    } catch (e) {
      setState(() => _isGeneratingAudio = false);
      print('❌ Audio generation failed: $e');
      _showMessage('❌ Audio generation failed', Colors.red);
    }
  }
  
  Future<void> _playAudioFile() async {
    if (_audioFilePath == null) {
      _showMessage('⚠️ No audio available', Colors.orange);
      return;
    }
    
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      await _flutterTts.stop();
      setState(() => _isPlayingAudio = false);
      _showMessage('⏹️ Audio stopped', Colors.orange);
      return;
    }
    
    try {
      setState(() => _isPlayingAudio = true);
      
      // Check if we're using live TTS mode
      if (_audioFilePath == 'LIVE_TTS') {
        print('🎤 Using live TTS mode');
        _showMessage('🎤 Playing live audio...', Colors.green);
        
        // Configure TTS
        await _configureTTSLanguage();
        
        // Set completion handler for TTS
        _flutterTts.setCompletionHandler(() {
          if (mounted) {
            setState(() => _isPlayingAudio = false);
            _showMessage('✅ Audio completed', Colors.blue);
          }
        });
        
        // Speak the result text
        await _flutterTts.speak(_result);
        
      } else {
        // Try to play audio file
        final file = File(_audioFilePath!);
        
        if (await file.exists()) {
          final fileSize = await file.length();
          print('📁 Playing audio file: ${file.path} (${fileSize} bytes)');
          
          if (fileSize > 0) {
            _showMessage('🔊 Playing audio file...', Colors.green);
            
            // Set up completion handler
            _audioPlayer.onPlayerComplete.listen((_) {
              if (mounted) {
                setState(() => _isPlayingAudio = false);
                _showMessage('✅ Audio playback completed', Colors.blue);
              }
            });
            
            // Play the audio file
            await _audioPlayer.play(DeviceFileSource(_audioFilePath!));
          } else {
            throw Exception('Audio file is empty');
          }
        } else {
          throw Exception('Audio file not found at: ${_audioFilePath}');
        }
      }
      
    } catch (e) {
      setState(() => _isPlayingAudio = false);
      print('❌ Audio playback error: $e');
      _showMessage('❌ Playback failed: ${e.toString()}', Colors.red);
      
      // Fallback to live TTS
      try {
        print('🔄 Falling back to live TTS...');
        setState(() => _isPlayingAudio = true);
        await _configureTTSLanguage();
        await _flutterTts.speak(_result);
        _showMessage('🎤 Playing with live TTS...', Colors.blue);
      } catch (fallbackError) {
        setState(() => _isPlayingAudio = false);
        _showMessage('❌ All audio methods failed', Colors.red);
      }
    }
  }
  
  Future<void> _downloadAudioFile() async {
    if (_audioFilePath == null) {
      _showMessage('⚠️ No audio available for download', Colors.orange);
      return;
    }
    
    try {
      if (_audioFilePath == 'LIVE_TTS') {
        // For live TTS mode, create a text file with the analysis
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'medical_analysis_$timestamp.txt';
        
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          final downloadPath = '${downloadsDir.path}/$fileName';
          final file = File(downloadPath);
          await file.writeAsString(_result);
          _showMessage('💾 Analysis saved as text: $fileName', Colors.green);
        } else {
          _showMessage('⚠️ Cannot access Downloads folder', Colors.orange);
        }
      } else {
        // For audio file mode
        final file = File(_audioFilePath!);
        if (await file.exists()) {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            final fileName = 'medical_analysis_${DateTime.now().millisecondsSinceEpoch}.wav';
            final downloadPath = '${downloadsDir.path}/$fileName';
            await file.copy(downloadPath);
            _showMessage('💾 Audio saved to Downloads/$fileName', Colors.green);
          } else {
            _showMessage('💾 Audio file at: ${file.path}', Colors.blue);
          }
        } else {
          _showMessage('❌ Audio file not found', Colors.red);
        }
      }
    } catch (e) {
      _showMessage('❌ Download failed: ${e.toString()}', Colors.red);
      print('Download error: $e');
    }
  }

  @override
  void dispose() {
    // Clean up TTS and AudioPlayer
    _flutterTts.stop();
    _audioPlayer.dispose();
    _isPlayingAudio = false;
    _isTTSInitialized = false;
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Off-white/Light Blue Grey
      appBar: AppBar(
        title: const Text(
          'MedReport',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1565C0), // Deep Medical Blue
        elevation: 0,
        centerTitle: false,
        actions: [
          // User Profile in AppBar
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _userName ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_userEmail != null)
                      Text(
                        _userEmail!.length > 15 
                          ? '${_userEmail!.substring(0, 15)}...'
                          : _userEmail!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _logout,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Modern Input Card
                  ModernInputCard(
                    controller: _controller,
                    selectedLanguage: _selectedLanguage,
                    imageBytes: _imageBytes,
                    selectedPdf: _selectedPdf,
                    onLanguageChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedLanguage = newValue;
                        });
                      }
                    },
                    onPickImage: _pickImage,
                    onPickPdf: _pickPdf,
                    onClear: _clearAll,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Results Section
                  if (_result.isNotEmpty) ...[
                    _buildResultsCard(),
                    const SizedBox(height: 100), // Space for bottom button
                  ],
                ],
              ),
            ),
          ),
          
          // Bottom Analyze Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _analyzeReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey[400],
                  ),
                  child: _isLoading 
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white, 
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Analyzing Report...', 
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_rounded, size: 22),
                          SizedBox(width: 12),
                          Text(
                            'Analyze Medical Report', 
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultsCard() {
    return Card(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded, 
                    color: Color(0xFF1565C0),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Medical Analysis ($_selectedLanguage)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 18,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Audio Controls
            Row(
              children: [
                Expanded(
                  child: _buildActionChip(
                    icon: _isPlayingAudio ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    label: _isPlayingAudio ? 'Stop Audio' : 'Play Audio',
                    color: _isPlayingAudio ? Colors.red : Colors.green,
                    onPressed: _audioFilePath != null ? _playAudioFile : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionChip(
                    icon: Icons.download_rounded,
                    label: 'Download',
                    color: const Color(0xFF1565C0),
                    onPressed: _audioFilePath != null ? _downloadAudioFile : null,
                  ),
                ),
              ],
            ),
            
            // Audio Status
            if (_isGeneratingAudio) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Generating audio...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
            
            if (_audioFilePath != null && !_isGeneratingAudio) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Audio ready',
                    style: TextStyle(color: Colors.green[600], fontSize: 12),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Analysis Text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _result,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Color(0xFF2E3A47),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: onPressed != null ? color.withOpacity(0.1) : Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: onPressed != null ? color.withOpacity(0.3) : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: onPressed != null ? color : Colors.grey[400],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: onPressed != null ? color : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}