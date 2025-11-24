import 'package:flutter/material.dart';

class InitialView extends StatelessWidget {
  final VoidCallback onStartRecording;

  const InitialView({Key? key, required this.onStartRecording}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      key: const ValueKey('initial'),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 48.0 : 64.0,
          horizontal: isSmallScreen ? 20.0 : 32.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_rounded,
                size: isSmallScreen ? 56 : 72,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            Text(
              "Ready to Transcribe",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 24 : 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Share an audio file or record live to get started",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            SizedBox(height: isSmallScreen ? 32 : 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStartRecording,
                icon: const Icon(Icons.mic, size: 24),
                label: Text(
                  "Start Live Recording",
                  style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
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
