import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProcessTimeline extends StatelessWidget {
  const ProcessTimeline({super.key});

  final List<Map<String, dynamic>> steps = const [
    {'title': 'Application', 'isCompleted': true, 'isActive': false},
    {'title': 'Written Test', 'isCompleted': true, 'isActive': false},
    {'title': 'AI Interview', 'isCompleted': false, 'isActive': true},
    {'title': 'Evaluation', 'isCompleted': false, 'isActive': false},
    {'title': 'Shortlisting', 'isCompleted': false, 'isActive': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
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
                          color: step['isActive']
                              ? const Color(0xFF6366F1)
                              : step['isCompleted']
                                  ? Colors.greenAccent
                                  : Colors.white24,
                          boxShadow: step['isActive']
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 40,
                          color: step['isCompleted']
                               ? Colors.white24
                               : Colors.white10,
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
                          step['title'],
                          style: TextStyle(
                            color: step['isActive'] || step['isCompleted']
                                ? Colors.white
                                : Colors.white54,
                            fontWeight: step['isActive']
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 16,
                          ),
                        ),
                        if (step['isActive'])
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'In Progress',
                              style: TextStyle(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                         const SizedBox(height: 32), // Spacing for next item
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
