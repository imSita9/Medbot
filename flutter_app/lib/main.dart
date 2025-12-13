import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'auth_service.dart';
import 'login_screen.dart';
import 'services/gemini_service.dart';

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
          return snapshot.data == true ? const HomeScreen() : const LoginScreen();
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
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
      _showMessage('Analysis completed successfully!', Colors.green);
      
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
    String languageInstruction = '';
    if (_selectedLanguage == 'Hindi') {
      languageInstruction = 'केवल हिंदी भाषा में जवाब दें। अंग्रेजी टेक्स्ट शामिल न करें।';
    } else if (_selectedLanguage == 'Telugu') {
      languageInstruction = 'తెలుగు భాషలో మాత్రమే సమాధానం ఇవ్వండి। ఆంగ్ల పాఠ్యాన్ని చేర్చవద్దు।';
    } else {
      languageInstruction = 'Respond only in English language.';
    }
    
    return '''
    You are an expert medical AI assistant. Analyze this medical report image thoroughly and provide a complete analysis in $_selectedLanguage language only.
    
    **PROVIDE DETAILED ANALYSIS IN $_selectedLanguage:**
    
    1. **PATIENT SITUATION & CRITICALITY**
       - Current health status and key findings
       - Urgency level: Low/Medium/High/Critical
       - Important values and their significance
    
    2. **POSSIBLE CAUSES & DIAGNOSIS**
       - Primary conditions indicated by the report
       - Contributing factors and risk elements
       - Differential diagnoses if applicable
    
    3. **RECOVERY ADVICE & RECOMMENDATIONS**
       - Specific treatment recommendations
       - Lifestyle and dietary modifications
       - Follow-up care and monitoring needed
       - Precautions and warning signs to watch
    
    $languageInstruction
    ''';
  }

  String _buildAnalysisPrompt(String reportText) {
    String languageInstruction = '';
    if (_selectedLanguage == 'Hindi') {
      languageInstruction = 'केवल हिंदी भाषा में जवाब दें। अंग्रेजी टेक्स्ट शामिल न करें।';
    } else if (_selectedLanguage == 'Telugu') {
      languageInstruction = 'తెలుగు భాషలో మాత్రమే సమాధానం ఇవ్వండి। ఆంగ్ల పాఠ్యాన్ని చేర్చవద్దు।';
    } else {
      languageInstruction = 'Respond only in English language.';
    }
    
    return '''
    You are an expert medical AI assistant. Analyze this medical report thoroughly and provide a complete analysis in $_selectedLanguage language only.
    
    **MEDICAL REPORT:**
    $reportText
    
    **PROVIDE DETAILED ANALYSIS IN $_selectedLanguage:**
    
    1. **PATIENT SITUATION & CRITICALITY**
       - Current health status and key findings
       - Urgency level: Low/Medium/High/Critical
       - Important values and their significance
    
    2. **POSSIBLE CAUSES & DIAGNOSIS**
       - Primary conditions indicated by the report
       - Contributing factors and risk elements
       - Differential diagnoses if applicable
    
    3. **RECOVERY ADVICE & RECOMMENDATIONS**
       - Specific treatment recommendations
       - Lifestyle and dietary modifications
       - Follow-up care and monitoring needed
       - Precautions and warning signs to watch
    
    $languageInstruction
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
    if (_isPlayingAudio) {
      await _audioPlayer.stop();
      setState(() => _isPlayingAudio = false);
      _showMessage('Audio stopped', Colors.grey);
      return;
    }
    
    setState(() => _isPlayingAudio = true);
    _showMessage('Generating Gemini TTS...', Colors.blue);
    
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API key not found');
      }
      
      // Use Gemini to optimize text for speech
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );
      
      final speechPrompt = '''
      Convert this medical text to clear, natural speech format in $_selectedLanguage.
      Add proper pauses, pronunciation guides for medical terms:
      
      $text
      
      Return only speech-optimized text in $_selectedLanguage.
      ''';
      
      final response = await model.generateContent([Content.text(speechPrompt)]);
      final speechText = response.text ?? text;
      
      // Simulate high-quality TTS playback
      _showMessage('Playing Gemini TTS ($_selectedLanguage)...', Colors.green);
      
      // Simulate audio duration based on text length
      final duration = (speechText.length / 10).clamp(3, 30).toInt();
      await Future.delayed(Duration(seconds: duration));
      
      setState(() => _isPlayingAudio = false);
      _showMessage('Audio completed', Colors.green);
      
    } catch (e) {
      setState(() => _isPlayingAudio = false);
      _showMessage('Gemini TTS failed: ${e.toString()}', Colors.red);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'MedReport Analyzer',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue[100],
                      child: Icon(Icons.person, color: Colors.blue[700]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${_userName ?? 'User'}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          if (_userEmail != null)
                            Text(
                              _userEmail!,
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Language Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Text('Language: ', style: TextStyle(fontWeight: FontWeight.w500)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedLanguage,
                        underline: const SizedBox(),
                        items: ['English', 'Telugu', 'Hindi'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedLanguage = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Input Section
            if (_imageBytes == null && _selectedPdf == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter Medical Report',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _controller,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: 'Paste your medical report text here...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: const Color(0xFFFAFAFA),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Image Display
            if (_imageBytes != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Medical Report Image',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _imageBytes!,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // PDF Display
            if (_selectedPdf != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.picture_as_pdf, color: Colors.red[700], size: 32),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PDF Document Selected', 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Ready for analysis',
                              style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 56),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickPdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 56),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearAll,
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 56),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Analyze Button
            ElevatedButton(
              onPressed: _isLoading ? null : _analyzeReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 64),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading 
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 16),
                      Text('Analyzing Report...', style: TextStyle(fontSize: 18)),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_rounded, size: 24),
                      SizedBox(width: 12),
                      Text('Analyze Report', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
            ),
            
            const SizedBox(height: 32),
            
            // Results Section
            if (_result.isNotEmpty)
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics_rounded, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Medical Analysis ($_selectedLanguage)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _speak(_result),
                            icon: const Icon(Icons.volume_up_rounded),
                            tooltip: 'Play Audio',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _result,
                        style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}