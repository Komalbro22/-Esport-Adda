import 'package:flutter/material.dart';
import 'stitch_theme.dart';

class SlotProgressBar extends StatelessWidget {
  final int joined;
  final int total;

  const SlotProgressBar({
    Key? key,
    required this.joined,
    required this.total,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = (joined / total).clamp(0.0, 1.0);
    final isFull = joined >= total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isFull ? 'FULLY JOINED' : 'SLOTS FILLED',
              style: TextStyle(
                color: isFull ? StitchTheme.error : StitchTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '$joined/$total',
              style: const TextStyle(
                color: StitchTheme.textMain,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: constraints.maxWidth * progress,
                    decoration: BoxDecoration(
                      gradient: StitchTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: StitchTheme.primary.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
