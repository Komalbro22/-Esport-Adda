import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'stitch_card.dart';
import 'stitch_theme.dart';

class StitchStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData? icon;
  final Color? color;

  const StitchStatCard({
    Key? key,
    required this.title,
    required this.value,
    this.icon,
    this.color,
  }) : super(key: key);

  @override
  State<StitchStatCard> createState() => _StitchStatCardState();
}

class _StitchStatCardState extends State<StitchStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? StitchTheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: StitchCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: StitchTheme.textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    widget.icon,
                    color: themeColor.withOpacity(0.8),
                    size: 20,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(
              widget.value,
              style: TextStyle(
                color: StitchTheme.textMain,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: themeColor.withOpacity(_isHovered ? 0.4 : 0.0),
                    blurRadius: 10,
                  )
                ],
              ),
            ),
          ],
        ),
      ).animate(target: _isHovered ? 1 : 0).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.02, 1.02),
            duration: 150.ms,
          ),
    );
  }
}
