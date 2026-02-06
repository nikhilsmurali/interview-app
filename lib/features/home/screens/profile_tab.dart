import 'package:ai_interviewer/core/services/theme_provider.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/home/screens/start_interview_screen.dart';
import 'package:ai_interviewer/features/home/widgets/consistency_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  Widget build(BuildContext context) {
    // Determine if we are in dark mode for dynamic colors 
    // (though Theme.of(context) handles most, some manual colors were hardcoded)
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final user = Provider.of<AuthService>(context).user;
    final userName = user?.displayName ?? 'Candidate';
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello,',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: subTextColor,
                          fontSize: 18,
                        ),
                  ),
                  Text(
                    userName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Theme Toggle
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      color: subTextColor,
                    ),
                    onPressed: () {
                      Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                    },
                  ),
                  // Logout
                  IconButton(
                    icon: Icon(Icons.logout, color: subTextColor),
                    onPressed: () {
                      Provider.of<AuthService>(context, listen: false).signOut();
                    },
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Action Buttons
          _buildActionButton(
            context,
            label: 'Start New Interview',
            icon: Icons.mic_none_rounded,
            color: const Color(0xFF6366F1),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StartInterviewScreen()),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          _buildActionButton(
            context,
            label: 'View Previous Reports',
            icon: Icons.assessment_outlined,
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
            textColor: textColor,
            iconColor: textColor,
            onTap: () {
              // TODO: Navigate to reports
            },
          ),

          const SizedBox(height: 48),

          // Consistency Tracker
          const ConsistencyHeatmap(),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Color textColor = Colors.white,
    Color? iconColor,
  }) {
    // For primary button (Start Interview), text is always white. 
    // For secondary, it adapts to theme.
    
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: color == const Color(0xFF6366F1)
                ? BorderSide.none
                : BorderSide(color: textColor.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: iconColor ?? textColor),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: iconColor ?? textColor),
          ],
        ),
      ),
    );
  }
}
