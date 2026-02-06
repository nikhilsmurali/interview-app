import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HowItWorksCarousel extends StatefulWidget {
  const HowItWorksCarousel({super.key});

  @override
  State<HowItWorksCarousel> createState() => _HowItWorksCarouselState();
}

class _HowItWorksCarouselState extends State<HowItWorksCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Enter Details',
      'description': 'Specify the company, role, and years of experience to tailor the interview.',
      'icon': Icons.edit_note_rounded,
    },
    {
      'title': 'AI Interview',
      'description': 'Answer technical questions generated specifically for your role by Gemini.',
      'icon': Icons.psychology_rounded,
    },
    {
      'title': 'Get Feedback',
      'description': 'Receive instant analysis on your answers and areas for improvement.',
      'icon': Icons.assessment_rounded,
    },
    {
      'title': 'Track Progress',
      'description': 'Monitor your consistency and growth over time with our tracker.',
      'icon': Icons.trending_up_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            children: [
              Text(
                'How it Works',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Carousel
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _steps.length,
            itemBuilder: (context, index) {
              final step = _steps[index];
              return _buildCarouselItem(step, index);
            },
          ),
        ),

        const SizedBox(height: 16),

        // Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_steps.length, (index) {
            final isSelected = _currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isSelected ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF6366F1) : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCarouselItem(Map<String, dynamic> step, int index) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double value = 1.0;
        if (_pageController.position.haveDimensions) {
          value = _pageController.page! - index;
          value = (1 - (value.abs() * 0.2)).clamp(0.8, 1.0);
        } else {
          // Initial state for first item
          value = index == 0 ? 1.0 : 0.8;
        }

        return Center(
          child: SizedBox(
            height: Curves.easeOut.transform(value) * 200,
            width: Curves.easeOut.transform(value) * 400,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(step['icon'], color: const Color(0xFF6366F1), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              step['title'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              step['description'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
