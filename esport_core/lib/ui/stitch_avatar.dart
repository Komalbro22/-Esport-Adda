import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'stitch_theme.dart';

class StitchAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final double? fontSize;
  final Color? backgroundColor;

  final double? borderWidth;
  final Color? borderColor;

  const StitchAvatar({
    super.key,
    this.avatarUrl,
    required this.name,
    this.radius = 40,
    this.fontSize,
    this.backgroundColor,
    this.borderWidth,
    this.borderColor,
  });

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      // "Komal Cheema" -> "KC"
      return (parts[0][0] + parts[1][0]).toUpperCase();
    } else if (name.length >= 2) {
      // "Komal" -> "KO"
      return name.substring(0, 2).toUpperCase();
    } else {
      return name.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    
    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? StitchTheme.surfaceHighlight,
      backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty) 
          ? CachedNetworkImageProvider(avatarUrl!) 
          : null,
      child: (avatarUrl == null || avatarUrl!.isEmpty)
          ? Text(
              initials,
              style: TextStyle(
                color: StitchTheme.primary,
                fontWeight: FontWeight.w900,
                fontSize: fontSize ?? radius * 0.45,
                letterSpacing: 1,
              ),
            )
          : null,
    );

    if (borderWidth != null && borderWidth! > 0) {
      return CircleAvatar(
        radius: radius + borderWidth!,
        backgroundColor: borderColor ?? StitchTheme.primary,
        child: avatar,
      );
    }

    return avatar;
  }
}
