import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProcessTimeline extends StatelessWidget {
  const ProcessTimeline({super.key});

  final List<Map<String, String>> steps = const [
    {'title': 'Enter interview details', 'subtitle': 'Specify role and topics'},
    {'title': 'Start interview', 'subtitle': 'AI-driven rapid fire questions'},
    {'title': 'Get feedback and report', 'subtitle': 'Detailed performance analysis'},
    {'title': 'Interacting with community', 'subtitle': 'Share and learn from others'},
    {'title': 'Promotion of consistency', 'subtitle': 'Track your daily progress'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it Works',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final isLast = index == steps.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline Line & Dot
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF6366F1), // Consistent accent color
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                          ],
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 50, // Slightly taller for subtitle space
                          color: Colors.white10,
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  // Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['title']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step['subtitle']!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                         const SizedBox(height: 24), // Spacing for next item
                      ],
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.2);
            },
          ),
        ],
      ),
    );
  }
}
