import 'package:flutter/material.dart';

class StitchGrid extends StatelessWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double spacing;
  final double childAspectRatio;

  const StitchGrid({
    Key? key,
    required this.children,
    this.crossAxisCount = 2,
    this.spacing = 16.0,
    this.childAspectRatio = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust for wider screens (Admin panel dashboard responsiveness)
        int calculatedCrossAxisCount = crossAxisCount;
        if (constraints.maxWidth > 1200) {
          calculatedCrossAxisCount = crossAxisCount * 2;
        } else if (constraints.maxWidth > 800) {
          calculatedCrossAxisCount = (crossAxisCount * 1.5).ceil();
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: calculatedCrossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) {
            return children[index];
          },
        );
      }
    );
  }
}
