import 'dart:async';
import 'package:flutter/material.dart';

class BodyLanguageHint {
  final String text;
  final IconData icon;
  final Color color;

  const BodyLanguageHint({
    required this.text,
    required this.icon,
    required this.color,
  });
}

class BodyLanguageHud extends StatefulWidget {
  final bool isCameraOff;
  final bool isSpeaking;
  final bool isListening;

  const BodyLanguageHud({
    super.key,
    required this.isCameraOff,
    required this.isSpeaking,
    required this.isListening,
  });

  @override
  State<BodyLanguageHud> createState() => _BodyLanguageHudState();
}

class _BodyLanguageHudState extends State<BodyLanguageHud> {
  int _currentHintIndex = 0;
  Timer? _hintRotationTimer;

  static const List<BodyLanguageHint> _hints = [
    BodyLanguageHint(
      text: 'Good eye contact',
      icon: Icons.visibility_rounded,
      color: Color(0xFF10B981), // Emerald
    ),
    BodyLanguageHint(
      text: 'Centered in frame',
      icon: Icons.center_focus_strong_rounded,
      color: Color(0xFF0EA5E9), // Sky Blue
    ),
    BodyLanguageHint(
      text: 'Steady speaking pace',
      icon: Icons.record_voice_over_rounded,
      color: Color(0xFFFF5A00), // Orange
    ),
    BodyLanguageHint(
      text: 'Engaged & attentive',
      icon: Icons.sentiment_very_satisfied_rounded,
      color: Color(0xFF8B5CF6), // Purple
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startHintRotation();
  }

  void _startHintRotation() {
    _hintRotationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && !widget.isCameraOff) {
        setState(() {
          _currentHintIndex = (_currentHintIndex + 1) % _hints.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _hintRotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCameraOff) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, color: Colors.white, size: 13),
            SizedBox(width: 5),
            Text(
              "Camera off — Proctor paused",
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final hint = _hints[_currentHintIndex];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(_currentHintIndex),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hint.color.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: hint.color.withValues(alpha: 0.25),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing indicator dot
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hint.color,
                boxShadow: [
                  BoxShadow(
                    color: hint.color,
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(hint.icon, color: hint.color, size: 13),
            const SizedBox(width: 5),
            Text(
              hint.text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
