import 'package:ai_interviewer/core/theme/app_theme.dart';
import 'package:ai_interviewer/features/auth/widgets/glass_container.dart';
import 'package:ai_interviewer/features/auth/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Elements
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
              ),
            ).animate().scale(duration: 2.seconds, curve: Curves.easeInOut).blur(begin: const Offset(100, 100)),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEC4899),
              ),
            ).animate().scale(duration: 2.seconds, delay: 500.ms).blur(begin: const Offset(120, 120)),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  GlassContainer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.psychology,
                          size: 80,
                          color: Colors.white,
                        ).animate().fadeIn().moveY(begin: 20, end: 0),
                        const SizedBox(height: 24),
                        Text(
                          'AI Interviewer',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 16),
                        Text(
                          'Master your interview skills with real-time AI feedback and speech analysis.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.white70,
                              ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 400.ms),
                      ],
                    ),
                  ),
                  const Spacer(),
                  PrimaryButton(
                    text: 'Get Started',
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                  ).animate().fadeIn(delay: 600.ms).moveY(begin: 20, end: 0),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: const Text('I already have an account'),
                  ).animate().fadeIn(delay: 800.ms),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
