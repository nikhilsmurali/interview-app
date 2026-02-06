import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ConsistencyHeatmap extends StatelessWidget {
  const ConsistencyHeatmap({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data: Generate random activity levels for the last 60 days
    final List<int> activityLevels = List.generate(60, (index) => Random().nextInt(5));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consistency Tracker',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: List.generate(activityLevels.length, (index) {
                  final level = activityLevels[index];
                  // Levels: 0 = empty, 1-4 = increasing intensity
                  final Color color = level == 0
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFF6366F1).withValues(
                          alpha: 0.2 + (level * 0.2).clamp(0.0, 0.8),
                        );

                  return Tooltip(
                    message: level == 0 ? 'No activity' : '$level contributions',
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ).animate().scale(delay: (index * 20).ms, duration: 200.ms);
                }),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Less', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  const SizedBox(width: 4),
                  _buildLegendBox(Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(width: 2),
                  _buildLegendBox(const Color(0xFF6366F1).withValues(alpha: 0.4)),
                  const SizedBox(width: 2),
                  _buildLegendBox(const Color(0xFF6366F1).withValues(alpha: 0.7)),
                  const SizedBox(width: 2),
                  _buildLegendBox(const Color(0xFF6366F1)),
                  const SizedBox(width: 4),
                  Text('More', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
