import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserHeaderCard extends StatelessWidget {
  final String selectedLanguage;
  final Function(String) onLanguageChanged;
  final String geminiApiKey;

  const UserHeaderCard({
    Key? key,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.geminiApiKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
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
                Expanded(
                  child: Text(
                    'Welcome, ${FirebaseAuth.instance.currentUser?.email ?? "User"}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
                    value: selectedLanguage,
                    underline: const SizedBox(),
                    items: ['Telugu', 'Hindi'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        onLanguageChanged(newValue);
                      }
                    },
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Audio test - TTS ready for medical reports'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.volume_up, size: 18),
                  label: const Text('Test Audio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}