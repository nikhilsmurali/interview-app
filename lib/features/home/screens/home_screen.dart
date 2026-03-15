import 'dart:ui' as ui;
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/home/screens/profile_tab.dart';
import 'package:ai_interviewer/features/home/widgets/ai_avatar.dart';
import 'package:ai_interviewer/features/home/widgets/how_it_works_carousel.dart';
import 'package:ai_interviewer/features/home/screens/start_interview_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ai_interviewer/features/home/screens/community_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const HomeDashboard(),
    const CommunityScreen(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), // Reduced side padding
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / 3;
                    return Stack(
                      children: [
                        // Animated Indicator
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutBack,
                          alignment: Alignment(_getIndicatorPosition(), 0),
                          child: Container(
                            width: itemWidth * 0.75,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5A00).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        // Icons
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildNavItem(0, Icons.home_rounded, 'Home', itemWidth),
                              _buildNavItem(1, Icons.people_rounded, 'Community', itemWidth),
                              _buildNavItem(2, Icons.person_rounded, 'Profile', itemWidth),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getIndicatorPosition() {
    // Map index 0, 1, 2 to Alignment horizontal values -0.66, 0.0, 0.66
    switch (_currentIndex) {
      case 0: return -0.9; 
      case 1: return 0.0;
      case 2: return 0.9;
      default: return 0.0;
    }
  }

  Widget _buildNavItem(int index, IconData icon, String label, double width) {
    final isSelected = _currentIndex == index;
    // Brighten the selected icon and maintain a clear unselected state
    final color = isSelected 
        ? const Color(0xFFFF7A20) // Brighter orange
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.4);
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: color, 
              size: 24, // Optimized size
            ),
          ],
        ),
      ),
    );
  }
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100), // Adjusted top padding to 0 as SafeArea handles it
      child: Column(
        children: [
          // 1. Top Header
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prepify',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                onPressed: () {
                   Provider.of<AuthService>(context, listen: false).signOut();
                },
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 2. Middle Portion (Avatar + Guide)
          Column(
            children: [
              // Avatar Video Loop
              const AiAvatar(),
              
              const SizedBox(height: 48),

              // Basic Guide / Timeline
              // How It Works Carousel
              const HowItWorksCarousel(),
              
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StartInterviewScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A00),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic_none_rounded, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Start New Interview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
