import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/home/screens/profile_tab.dart';
import 'package:ai_interviewer/features/home/widgets/ai_avatar.dart';
import 'package:ai_interviewer/features/home/widgets/how_it_works_carousel.dart';
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
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.9),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF6366F1),
          unselectedItemColor: Colors.white38,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Community'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
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
      child: Column(
        children: [
          // 1. Top Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Prepify',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70),
                  onPressed: () {
                     Provider.of<AuthService>(context, listen: false).signOut();
                  },
                ),
              ],
            ),
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
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
