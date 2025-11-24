import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  final String statusMessage;

  const LoadingView({Key? key, required this.statusMessage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Card(
      key: const ValueKey('loading'),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 48.0 : 60.0,
          horizontal: isSmallScreen ? 20.0 : 32.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: isSmallScreen ? 56 : 72,
              height: isSmallScreen ? 56 : 72,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            Text(
              statusMessage,
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 22,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "This may take a few moments",
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
