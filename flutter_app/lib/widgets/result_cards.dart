import 'package:flutter/material.dart';

class ResultCards extends StatelessWidget {
  final String result;
  final String translation;
  final String selectedLanguage;
  final Function(String) onSpeak;

  const ResultCards({
    Key? key,
    required this.result,
    required this.translation,
    required this.selectedLanguage,
    required this.onSpeak,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (result.isNotEmpty)
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
                    result,
                    style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
          ),
        
        if (translation.isNotEmpty)
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
                          '$selectedLanguage Translation',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => onSpeak(translation),
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
                    translation,
                    style: TextStyle(fontSize: 16, height: 1.6, color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}