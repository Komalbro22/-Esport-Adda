import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'stitch_theme.dart';

class StitchShimmer extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Widget? child;

  const StitchShimmer({
    Key? key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius,
    this.child,
  }) : super(key: key);

  factory StitchShimmer.rectangular({
    double width = double.infinity,
    double height = 20,
    BorderRadius? borderRadius,
  }) => StitchShimmer(
    width: width,
    height: height,
    borderRadius: borderRadius ?? BorderRadius.circular(4),
  );

  factory StitchShimmer.circular({
    double size = 40,
    BorderRadius? borderRadius,
  }) => StitchShimmer(
    width: size,
    height: size,
    borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
  );

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: StitchTheme.surface,
      highlightColor: StitchTheme.surfaceHighlight.withOpacity(0.5),
      period: const Duration(milliseconds: 1500),
      child: child ?? Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class TournamentShimmer extends StatelessWidget {
  const TournamentShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: StitchTheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StitchShimmer.rectangular(height: 140, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StitchShimmer.rectangular(width: 150, height: 20),
                const SizedBox(height: 12),
                StitchShimmer.rectangular(height: 60, borderRadius: BorderRadius.circular(16)),
                const SizedBox(height: 16),
                StitchShimmer.rectangular(height: 40, borderRadius: BorderRadius.circular(12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
