import 'package:flutter/material.dart';
import 'stitch_theme.dart';

class StitchSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    bool isSuccess = false,
  }) {
    Color backgroundColor = StitchTheme.surfaceHighlight;
    IconData icon = Icons.info_outline_rounded;
    Color iconColor = StitchTheme.primary;

    if (isError) {
      backgroundColor = StitchTheme.error.withOpacity(0.9);
      icon = Icons.error_outline_rounded;
      iconColor = Colors.white;
    } else if (isSuccess) {
      backgroundColor = StitchTheme.success.withOpacity(0.9);
      icon = Icons.check_circle_outline_rounded;
      iconColor = Colors.white;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 8,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  
  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, isSuccess: true);
  }
  
  static void showError(BuildContext context, String message) {
    show(context, message: message, isError: true);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message: message);
  }
}
