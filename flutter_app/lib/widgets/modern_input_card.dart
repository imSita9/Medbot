import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';

class ModernInputCard extends StatelessWidget {
  final TextEditingController controller;
  final String selectedLanguage;
  final Uint8List? imageBytes;
  final File? selectedPdf;
  final ValueChanged<String?> onLanguageChanged;
  final VoidCallback onPickImage;
  final VoidCallback onPickPdf;
  final VoidCallback onClear;

  const ModernInputCard({
    super.key,
    required this.controller,
    required this.selectedLanguage,
    required this.imageBytes,
    required this.selectedPdf,
    required this.onLanguageChanged,
    required this.onPickImage,
    required this.onPickPdf,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medical_information_rounded,
                    color: Color(0xFF1565C0),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Medical Report Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Content based on selection
            if (imageBytes == null && selectedPdf == null) ...[
              // Text Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Paste your medical report text here...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            
            // Image Display
            if (imageBytes != null) ...[
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.image_rounded, color: Colors.teal, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Medical Report Image',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          imageBytes!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // PDF Display
            if (selectedPdf != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PDF Document Selected',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'Ready for analysis',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Action Chips Row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildActionChip(
                    icon: Icons.camera_alt_rounded,
                    label: 'Scan',
                    color: Colors.teal,
                    onPressed: onPickImage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildActionChip(
                    icon: Icons.upload_file_rounded,
                    label: 'PDF',
                    color: Colors.orange,
                    onPressed: onPickPdf,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.grey[600],
                    minimumSize: const Size(40, 40),
                  ),
                  tooltip: 'Clear All',
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Divider
            Divider(color: Colors.grey[200]),
            
            const SizedBox(height: 16),
            
            // Language Selector
            Row(
              children: [
                const Text(
                  'Output Language',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2E3A47),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedLanguage,
                      onChanged: onLanguageChanged,
                      style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w500,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'English', child: Text('English')),
                        DropdownMenuItem(value: 'Telugu', child: Text('Telugu')),
                        DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
                      ],
                    ),
                  ),
                ),
              ],
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}