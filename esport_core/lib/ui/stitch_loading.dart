import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'stitch_theme.dart';

class StitchLoading extends StatelessWidget {
  const StitchLoading({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: StitchTheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: StitchTheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              color: StitchTheme.primary,
              strokeWidth: 3,
            ),
          ).animate(onPlay: (controller) => controller.repeat())
           .shimmer(duration: 2000.ms, color: Colors.white24),
        ],
      ),
    );
  }
}
