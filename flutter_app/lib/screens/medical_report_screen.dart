import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../widgets/modern_input_card.dart';
import '../auth_service.dart';
import '../login_screen.dart';

class MedicalReportScreen extends StatefulWidget {
  const MedicalReportScreen({super.key});

  @override
  State<MedicalReportScreen> createState() => _MedicalReportScreenState();
}

class _MedicalReportScreenState extends State<MedicalReportScreen> {
  final TextEditingController _textController = TextEditingController();
  String _selectedLanguage = 'English';
  Uint8List? _imageBytes;
  File? _selectedPdf;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _result = '';
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  @override
  void dispose() {
    _textController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    // Configure TTS for speaker output
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.6);
    await _flutterTts.setPitch(1.0);
    
    // Force audio to speaker
    await _flutterTts.setSharedInstance(true);
    await _flutterTts.awaitSpeakCompletion(true);
    
    // Set audio session category for playback
    try {
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [IosTextToSpeechAudioCategoryOptions.allowBluetooth],
        IosTextToSpeechAudioMode.defaultMode,
      );
    } catch (e) {
      print('iOS audio category not available on Android');
    }
    
    _flutterTts.setStartHandler(() {
      print('🔊 TTS Started - Audio should play through speaker');
      setState(() => _isPlaying = true);
    });
    
    _flutterTts.setCompletionHandler(() {
      print('✅ TTS Completed');
      setState(() => _isPlaying = false);
    });
    
    _flutterTts.setErrorHandler((msg) {
      print('❌ TTS Error: $msg');
      setState(() => _isPlaying = false);
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _selectedPdf = null;
        _textController.clear();
      });
    }
  }

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    
    if (result != null) {
      setState(() {
        _selectedPdf = File(result.files.single.path!);
        _imageBytes = null;
        _textController.clear();
      });
    }
  }

  void _clearAll() {
    setState(() {
      _imageBytes = null;
      _selectedPdf = null;
      _textController.clear();
    });
  }

  Future<void> _analyzeReport() async {
    final inputText = _textController.text.trim();
    
    if (inputText.isEmpty && _imageBytes == null && _selectedPdf == null) {
      _showMessage('Please enter text, select image, or choose PDF', Colors.orange);
      return;
    }
    
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API key not found');
      }

      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
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

      final response = await model.generateContent(content);
      final result = response.text ?? 'No analysis available';
      
      setState(() {
        _result = result;
      });
      
      await _generateOptimizedTts(result);
      _showMessage('Analysis completed!', Colors.green);
      
    } catch (e) {
      _showMessage('Error: ${e.toString()}', Colors.red);
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _buildImageAnalysisPrompt() {
    return '''
    You are an experienced medical assistant. Analyze the attached medical report image and provide a concise summary in $_selectedLanguage.

    Your response must be in plain text only. Use the following structure:

    Condition: briefly identify the primary diagnosis or finding
    Urgency: specify if this is Low, Medium, High, or Critical

    Foods to Eat: list beneficial foods that aid recovery
    Foods to Avoid: list foods that may worsen the condition

    Action: list the key medical recommendations

    Keep the entire response under 300 words.
    ''';
  }

  String _buildAnalysisPrompt(String reportText) {
    return '''
    You are an experienced medical assistant. Analyze the medical report text and provide a concise summary in $_selectedLanguage.

    Medical Report Text: $reportText

    Your response must be in plain text only. Use the following structure:

    Condition: briefly identify the primary diagnosis or finding
    Urgency: specify if this is Low, Medium, High, or Critical

    Foods to Eat: list beneficial foods that aid recovery
    Foods to Avoid: list foods that may worsen the condition

    Action: list the key medical recommendations

    Keep the entire response under 300 words.
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

  Future<void> _logout() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _generateOptimizedTts(String text) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null) return;
      
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
      final prompt = '''
      Convert this medical analysis to natural, clear speech in $_selectedLanguage.
      Make it easy to understand when spoken aloud:
      
      $text
      
      Requirements:
      - Use simple, clear language
      - Add natural pauses with punctuation
      - Keep medical accuracy
      - No emojis or special symbols
      - Maximum 250 words
      - Return only the speech-ready text in $_selectedLanguage
      ''';
      
      final response = await model.generateContent([Content.text(prompt)]);
      final optimizedText = response.text ?? text;
      
      await _configureTtsLanguage();
    } catch (e) {
      print('TTS optimization failed: $e');
    }
  }

  Future<void> _configureTtsLanguage() async {
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
    
    // Set language and ensure audio routing
    await _flutterTts.setLanguage(languageCode);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.6);
    
    print('🌍 Language configured: $languageCode with volume: 1.0');
  }

  Future<void> _playTts() async {
    if (_isPlaying) {
      await _flutterTts.stop();
      setState(() => _isPlaying = false);
      _showMessage('Audio stopped', Colors.orange);
      return;
    }
    
    if (_result.isEmpty) {
      _showMessage('No analysis to play', Colors.orange);
      return;
    }
    
    try {
      // Test with simple text first
      await _testTtsVolume();
      
      // Configure audio before speaking
      await _configureTtsLanguage();
      
      // Ensure maximum volume and speaker output
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSharedInstance(true);
      
      setState(() => _isPlaying = true);
      
      // Use a shorter test text if result is too long
      String textToSpeak = _result.length > 200 ? 
        _result.substring(0, 200) + '... Audio test complete.' : _result;
      
      // Speak with explicit await
      final result = await _flutterTts.speak(textToSpeak);
      
      if (result == 1) {
        print('🎤 TTS started successfully');
        _showMessage('🔊 Audio playing - Check volume!', Colors.green);
      } else {
        print('❌ TTS failed to start: $result');
        setState(() => _isPlaying = false);
        _showMessage('Audio failed to start', Colors.red);
      }
      
    } catch (e) {
      print('❌ TTS Error: $e');
      setState(() => _isPlaying = false);
      _showMessage('Audio error: ${e.toString()}', Colors.red);
    }
  }
  
  Future<void> _testTtsVolume() async {
    try {
      // Quick volume test with English
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.8);
      
      // Test speak without changing state
      print('🔊 Testing TTS volume...');
      
    } catch (e) {
      print('Volume test failed: $e');
    }
  }
  
  Future<void> _testVolume() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.8);
      
      _showMessage('🔊 Volume test - Check your device volume!', Colors.blue);
      
      final result = await _flutterTts.speak('Volume test. Can you hear this? Please check your device volume settings.');
      
      if (result == 1) {
        print('🔊 Volume test started');
      } else {
        _showMessage('Volume test failed', Colors.red);
      }
      
    } catch (e) {
      _showMessage('Volume test error: ${e.toString()}', Colors.red);
    }
  }

  bool get _hasContent => 
      _textController.text.isNotEmpty || _imageBytes != null || _selectedPdf != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'MedReport',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _logout,
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ModernInputCard(
                    controller: _textController,
                    selectedLanguage: _selectedLanguage,
                    imageBytes: _imageBytes,
                    selectedPdf: _selectedPdf,
                    onLanguageChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _selectedLanguage = value;
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
                    const SizedBox(height: 100),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                  onPressed: _isLoading ? null : (_hasContent ? _analyzeReport : null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                            'Analyzing...', 
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_rounded,
                            size: 20,
                            color: _hasContent ? Colors.white : Colors.grey[500],
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Analyze Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _hasContent ? Colors.white : Colors.grey[500],
                            ),
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
                  flex: 2,
                  child: _buildActionChip(
                    icon: _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    label: _isPlaying ? 'Stop Audio' : 'Play Audio',
                    color: _isPlaying ? Colors.red : Colors.green,
                    onPressed: _playTts,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildActionChip(
                    icon: Icons.volume_up_rounded,
                    label: 'Test',
                    color: Colors.blue,
                    onPressed: _testVolume,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
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
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}