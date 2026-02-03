import 'package:ai_interviewer/core/services/firebase_service.dart';
import 'package:ai_interviewer/core/theme/app_theme.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/auth/screens/landing_page.dart';
import 'package:ai_interviewer/features/auth/screens/login_screen.dart';
import 'package:ai_interviewer/features/auth/screens/signup_screen.dart';
import 'package:ai_interviewer/features/home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(const AiInterviewerApp());
}

class AiInterviewerApp extends StatelessWidget {
  const AiInterviewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'AI Interviewer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        // Removed initialRoute to let 'home' handle the logic
        home: const AuthWrapper(), 
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    // We can also listen to the stream directly if needed, 
    // but AuthService updates on changes too.
    if (authService.user != null) {
      return const HomeScreen();
    } else {
      return const LandingPage();
    }
  }
}
