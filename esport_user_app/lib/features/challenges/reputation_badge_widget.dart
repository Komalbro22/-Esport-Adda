import 'package:flutter/material.dart';
import 'package:esport_core/esport_core.dart';

enum ReputationBadgeType {
  veteran('VETERAN', Color(0xFFE91E63), Icons.workspace_premium_rounded),
  trusted('TRUSTED', Color(0xFF00E676), Icons.verified_user_rounded),
  normal('NORMAL PLAYER', Color(0xFF2196F3), Icons.person_rounded),
  risk('RISK PLAYER', Color(0xFFFFAB40), Icons.warning_rounded),
  dangerous('DANGEROUS PLAYER', Color(0xFFFF5252), Icons.gavel_rounded);

  final String label;
  final Color color;
  final IconData icon;
  const ReputationBadgeType(this.label, this.color, this.icon);

  static ReputationBadgeType fromScore(int score) {
    if (score >= 95) return ReputationBadgeType.veteran;
    if (score >= 85) return ReputationBadgeType.trusted;
    if (score >= 70) return ReputationBadgeType.normal;
    if (score >= 50) return ReputationBadgeType.risk;
    return ReputationBadgeType.dangerous;
  }
}

class ReputationBadge extends StatelessWidget {
  final int score;
  final bool showLabel;
  final double fontSize;

  const ReputationBadge({
    Key? key,
    required this.score,
    this.showLabel = true,
    this.fontSize = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final badge = ReputationBadgeType.fromScore(score);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badge.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badge.color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.icon, size: fontSize + 4, color: badge.color),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              badge.label,
              style: TextStyle(
                color: badge.color,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
