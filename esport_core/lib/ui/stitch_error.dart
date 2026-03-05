import 'package:flutter/material.dart';
import 'stitch_theme.dart';
import 'stitch_button.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StitchError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const StitchError({
    Key? key,
    required this.message,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: StitchTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: StitchTheme.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Oops! Something went wrong.",
              style: const TextStyle(
                color: StitchTheme.textMain,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: StitchTheme.textMuted,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              SizedBox(
                width: 200,
                child: StitchButton(
                  text: 'Try Again',
                  onPressed: onRetry,
                  isSecondary: true,
                ),
              ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
      ),
    );
  }
}
