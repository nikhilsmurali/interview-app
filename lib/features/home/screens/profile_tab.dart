import 'package:ai_interviewer/core/services/theme_provider.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/home/widgets/consistency_heatmap.dart';
import 'package:ai_interviewer/features/home/screens/reports_list_screen.dart';
import 'package:ai_interviewer/features/auth/screens/preferences_onboarding_screen.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthService>(context).user;
    final userName = user?.displayName ?? 'Candidate';
    final textColor = Theme.of(context).colorScheme.onSurface;
    final subTextColor = textColor.withOpacity(0.7);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
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


          _buildActionButton(
            context,
            label: 'View Previous Reports',
            icon: Icons.assessment_outlined,
            color: Theme.of(context).colorScheme.surface,
            textColor: textColor,
            iconColor: textColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsListScreen()),
              );
            },
          ),

          const SizedBox(height: 16),

          _buildActionButton(
            context,
            label: 'Edit Content Preferences',
            icon: Icons.settings_suggest_outlined,
            color: Theme.of(context).colorScheme.surface,
            textColor: textColor,
            iconColor: textColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PreferencesOnboardingScreen(isEditing: true)),
              );
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
            side: color == const Color(0xFFFF5A00)
                ? BorderSide.none
                : BorderSide(color: textColor.withOpacity(0.1)),
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
