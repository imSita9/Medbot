import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onImagePick;
  final VoidCallback onPdfPick;
  final VoidCallback onClear;
  final Animation<double> scaleAnimation;

  const ActionButtons({
    Key? key,
    required this.onImagePick,
    required this.onPdfPick,
    required this.onClear,
    required this.scaleAnimation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        
        return Row(
          children: [
            Expanded(
              child: ScaleTransition(
                scale: scaleAnimation,
                child: ElevatedButton.icon(
                  onPressed: onImagePick,
                  icon: const Icon(Icons.image_rounded),
                  label: Text(isTablet ? 'Select Image' : 'Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    minimumSize: Size(0, isTablet ? 64 : 56),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ScaleTransition(
                scale: scaleAnimation,
                child: ElevatedButton.icon(
                  onPressed: onPdfPick,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(isTablet ? 'Select PDF' : 'PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    foregroundColor: Colors.white,
                    minimumSize: Size(0, isTablet ? 64 : 56),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ScaleTransition(
                scale: scaleAnimation,
                child: ElevatedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_rounded),
                  label: Text(isTablet ? 'Clear All' : 'Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    minimumSize: Size(0, isTablet ? 64 : 56),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}