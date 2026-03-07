import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'stitch_theme.dart';
import 'stitch_button.dart';

class StitchDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    String? primaryButtonText,
    VoidCallback? onPrimaryPressed,
    Color? primaryButtonColor,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Wrap(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: StitchTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: StitchTheme.surfaceHighlight,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: StitchTheme.textMain,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DefaultTextStyle(
                        style: const TextStyle(
                          color: StitchTheme.textMuted,
                          fontSize: 16,
                          height: 1.5,
                        ),
                        child: content,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          if (secondaryButtonText != null) ...[
                            Expanded(
                              child: StitchButton(
                                text: secondaryButtonText,
                                onPressed: onSecondaryPressed ?? () => Navigator.of(context).pop(),
                                isSecondary: true,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (primaryButtonText != null)
                            Expanded(
                              child: StitchButton(
                                text: primaryButtonText,
                                onPressed: onPrimaryPressed,
                                customColor: primaryButtonColor,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * animation.value,
            sigmaY: 8 * animation.value,
          ),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
