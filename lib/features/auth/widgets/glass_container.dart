import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderOpacity;
  final double bgOpacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 15,
    this.borderOpacity = 0.2,
    this.bgOpacity = 0.1,
    this.borderRadius,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: bgOpacity),
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: borderOpacity),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
