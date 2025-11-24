import 'dart:ui';
import 'package:flutter/material.dart';

class RecordingView extends StatelessWidget {
  final int duration;
  final VoidCallback onStopRecording;

  const RecordingView({
    Key? key,
    required this.duration,
    required this.onStopRecording,
  }) : super(key: key);

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      key: const ValueKey('liveRecording'),
      color: Colors.red.shade50,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 48.0 : 60.0,
          horizontal: isSmallScreen ? 20.0 : 32.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: isSmallScreen ? 100 : 120,
                  height: isSmallScreen ? 100 : 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.shade100,
                  ),
                ),
                Icon(
                  Icons.mic,
                  size: isSmallScreen ? 48 : 56,
                  color: Colors.red.shade700,
                ),
                Positioned(
                  top: isSmallScreen ? 8 : 10,
                  right: isSmallScreen ? 8 : 10,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            Text(
              "Recording...",
              style: TextStyle(
                fontSize: isSmallScreen ? 24 : 28,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _formatDuration(duration),
              style: TextStyle(
                fontSize: isSmallScreen ? 32 : 40,
                fontWeight: FontWeight.w300,
                color: Colors.red.shade800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            SizedBox(height: isSmallScreen ? 32 : 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStopRecording,
                icon: const Icon(Icons.stop, size: 24),
                label: Text(
                  "Stop & Transcribe",
                  style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, isSmallScreen ? 56 : 64),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
