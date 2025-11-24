import 'package:flutter/material.dart';

class FileSharedView extends StatelessWidget {
  final String fileName;
  final VoidCallback onStartTranscription;

  const FileSharedView({
    Key? key,
    required this.fileName,
    required this.onStartTranscription,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
      key: const ValueKey('fileShared'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.audio_file_rounded,
                    color: Colors.green.shade600,
                    size: isSmallScreen ? 28 : 36,
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Ready to transcribe",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onStartTranscription,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, isSmallScreen ? 56 : 64),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.transcribe_rounded, size: 24),
              const SizedBox(width: 12),
              Text(
                "Start Transcription",
                style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
