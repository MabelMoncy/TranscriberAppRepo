import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SuccessView extends StatelessWidget {
  final String? transcribedText;
  final VoidCallback onReset;
  final VoidCallback onCopy;

  const SuccessView({
    Key? key,
    required this.transcribedText,
    required this.onReset,
    required this.onCopy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
      key: const ValueKey('success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: isSmallScreen ? 24 : 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Transcription Complete",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      tooltip: "Copy to clipboard",
                      onPressed: onCopy,
                      iconSize: isSmallScreen ? 22 : 24,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(
                    transcribedText ?? "No text found.",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        OutlinedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.refresh_rounded, size: 24),
          label: Text(
            "Transcribe Another",
            style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
            minimumSize: Size(double.infinity, isSmallScreen ? 56 : 64),
          ),
        ),
      ],
    );
  }
}
