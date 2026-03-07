import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'stitch_theme.dart';

class StitchButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? customColor;

  const StitchButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.backgroundColor,
    this.textColor,
    this.customColor,
  }) : super(key: key);

  @override
  State<StitchButton> createState() => _StitchButtonState();
}

class _StitchButtonState extends State<StitchButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: (widget.isSecondary || widget.backgroundColor != null || widget.customColor != null) ? null : StitchTheme.primaryGradient,
            color: widget.customColor ?? widget.backgroundColor ?? (widget.isSecondary ? Colors.transparent : null),
            border: widget.isSecondary ? Border.all(color: widget.customColor ?? StitchTheme.primary.withOpacity(0.5), width: 1.5) : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isHovered && !widget.isLoading && widget.onPressed != null
                ? [
                    BoxShadow(
                      color: widget.isSecondary 
                        ? (widget.customColor ?? StitchTheme.primary).withOpacity(0.2) 
                        : (widget.customColor ?? StitchTheme.primary).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: widget.isSecondary ? (widget.customColor ?? StitchTheme.primary) : StitchTheme.textMain,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.text,
                    style: TextStyle(
                      color: widget.textColor ?? StitchTheme.textMain,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ).animate(target: _isHovered ? 1 : 0).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.02, 1.02),
            duration: 150.ms,
          ),
    );
  }
}
