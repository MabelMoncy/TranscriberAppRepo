import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  final String? errorMessage;
  final bool isAccidental;
  final VoidCallback onRetry;

  const ErrorView({
    Key? key,
    required this.errorMessage,
    required this.isAccidental,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Column(
      key: const ValueKey('error'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: isAccidental ? Colors.orange.shade50 : Colors.red.shade50,
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
                        color: isAccidental 
                            ? Colors.orange.shade100 
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isAccidental 
                            ? Icons.warning_amber_rounded 
                            : Icons.error_outline_rounded,
                        color: isAccidental 
                            ? Colors.orange.shade700 
                            : Colors.red.shade700,
                        size: isSmallScreen ? 24 : 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isAccidental 
                            ? "Accidental Recording" 
                            : "Error Occurred",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: isAccidental 
                              ? Colors.orange.shade900 
                              : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SelectableText(
                    errorMessage ?? "An unknown error occurred.",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 15 : 17,
                      height: 1.6,
                      color: isAccidental 
                          ? Colors.orange.shade900 
                          : Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 24),
          label: Text(
            "Try Again",
            style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, isSmallScreen ? 56 : 64),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}
