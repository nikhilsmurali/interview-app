import 'dart:math' as math;
import 'package:flutter/material.dart';

class LiveAudioWaveform extends StatefulWidget {
  final bool isListening;
  final bool hasDetectedSpeech;
  final Color activeColor;

  const LiveAudioWaveform({
    super.key,
    required this.isListening,
    this.hasDetectedSpeech = false,
    this.activeColor = const Color(0xFFFF5A00),
  });

  @override
  State<LiveAudioWaveform> createState() => _LiveAudioWaveformState();
}

class _LiveAudioWaveformState extends State<LiveAudioWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isListening) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = _controller.value * 2 * math.pi;

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pulsing Mic Icon Badge
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.activeColor.withValues(alpha: 0.2),
                boxShadow: [
                  BoxShadow(
                    color: widget.activeColor.withValues(
                      alpha: 0.2 + 0.3 * math.sin(t).abs(),
                    ),
                    blurRadius: 10 + 6 * math.sin(t).abs(),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.mic,
                size: 14,
                color: widget.activeColor,
              ),
            ),
            const SizedBox(width: 8),

            // Animated Waveform Bars (7 bars)
            ...List.generate(7, (index) {
              // Create harmonious sinusoidal heights with phase offsets
              final phase = index * 0.8;
              final speechBoost = widget.hasDetectedSpeech ? 1.4 : 0.8;
              final heightFactor = (0.3 + 0.7 * (0.5 + 0.5 * math.sin(t + phase))) * speechBoost;
              final double barHeight = (8.0 + (16.0 * heightFactor)).clamp(6.0, 26.0);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 3.5,
                height: barHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.activeColor,
                      const Color(0xFFFF944D),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
