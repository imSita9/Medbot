import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const MedReportApp());
}

class MedReportApp extends StatelessWidget {
  const MedReportApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedReport Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  String _result = '';
  String _translation = '';
  bool _isLoading = false;
  String _selectedLanguage = 'Telugu';
  File? _selectedPdf;
  Uint8List? _imageBytes;
  
  static const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  final ImagePicker _picker = ImagePicker();

  Future<void> _analyzeReport() async {
    final inputText = _controller.text.trim();
    
    if (inputText.isEmpty && _imageBytes == null && _selectedPdf == null) {
      _showMessage('Please enter text, select image, or choose PDF', Colors.orange);
      return;
    }
    
    setState(() {
      _isLoading = true;
      _result = '';
      _translation = '';
    });

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash', 
        apiKey: _geminiApiKey,
      );

      final content = <Content>[];
      
      if (_imageBytes != null) {
        content.add(Content.multi([
          TextPart('''Analyze this medical report image. Provide:
          1. Patient Situation & Criticality Level (Low/Medium/High/Critical)
          2. Possible Causes
          3. Recovery Advice
          4. Translate everything to $_selectedLanguage
          
          Format:
          ENGLISH: [Analysis in English]
          TRANSLATION: [Analysis in $_selectedLanguage]'''),
          DataPart('image/jpeg', _imageBytes!)
        ]));
      } else if (_selectedPdf != null) {
        final pdfText = await _extractPdfText(_selectedPdf!);
        content.add(Content.text(_buildAnalysisPrompt(pdfText)));
      } else if (inputText.isNotEmpty) {
        content.add(Content.text(_buildAnalysisPrompt(inputText)));
      }

      final response = await model.generateContent(content);
      final text = response.text ?? 'No response';
      
      _parseResponse(text);
      _showMessage('Analysis completed!', Colors.green);
      
    } catch (e) {
      _showMessage('Analysis failed: ${e.toString()}', Colors.red);
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _buildAnalysisPrompt(String reportText) {
    return '''
    Analyze this medical report and provide:
    1. Patient Situation & Criticality
    2. Possible Causes
    3. Recovery Advice
    4. Translation to $_selectedLanguage
    
    Medical Report: $reportText
    
    Format:
    ENGLISH: 
    ## Patient Situation
    [Details]
    ## Causes
    [Details]
    ## Advice
    [Details]
    
    TRANSLATION:
    [Translate all above to $_selectedLanguage]
    ''';
  }
  
  void _parseResponse(String text) {
    final parts = text.split('TRANSLATION:');
    if (parts.length >= 2) {
      _result = parts[0].replaceAll('ENGLISH:', '').trim();
      _translation = parts[1].trim();
    } else {
      _result = text;
      _translation = 'Translation not found. Showing full response below.';
    }
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
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _selectedPdf = null;
          _controller.clear();
        });
        _showMessage('Image selected successfully!', Colors.green);
      }
    } catch (e) {
      _showMessage('Image selection failed: $e', Colors.red);
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
      _translation = '';
    });
    _showMessage('All data cleared', Colors.grey);
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
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Icon(Icons.person, color: Colors.blue[700]),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Welcome to MedReport Analyzer',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
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
                            items: ['Telugu', 'Hindi'].map((String value) {
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
                          const Text(
                            'Medical Analysis',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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
            
            if (_translation.isNotEmpty)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.translate_rounded, color: Colors.green[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '$_selectedLanguage Translation',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _translation,
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