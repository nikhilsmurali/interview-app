import 'package:ai_interviewer/features/auth/widgets/auth_text_field.dart';
import 'package:ai_interviewer/features/auth/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background
           Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Create Account',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ).animate().fadeIn().moveX(begin: -20, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    'Sign up to start your journey',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white70,
                        ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 48),
                  
                  AuthTextField(
                    hintText: 'Full Name',
                    icon: Icons.person_outline,
                  ).animate().fadeIn(delay: 300.ms).moveY(begin: 20, end: 0),
                  const SizedBox(height: 16),
                  
                  AuthTextField(
                    hintText: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ).animate().fadeIn(delay: 400.ms).moveY(begin: 20, end: 0),
                  const SizedBox(height: 16),
                  
                  AuthTextField(
                    hintText: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ).animate().fadeIn(delay: 500.ms).moveY(begin: 20, end: 0),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: 'Sign Up',
                      onPressed: () {
                        // TODO: Implement Signup Logic
                      },
                    ),
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 16),
                  
                  Center(
                    child: Text(
                      'OR',
                      style: const TextStyle(color: Colors.white38),
                    ),
                  ).animate().fadeIn(delay: 650.ms),
                  
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const FaIcon(FontAwesomeIcons.google, color: Colors.white),
                      label: const Text(
                        'Sign up with Google',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () async {
                         final authService = Provider.of<AuthService>(context, listen: false);
                        final user = await authService.signInWithGoogle();
                        if (context.mounted && user != null) {
                           // Navigation handled by main.dart AuthWrapper stream.
                           Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                      },
                    ),
                  ).animate().fadeIn(delay: 700.ms),
                  
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () {
                         Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: RichText(
                        text: const TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: Colors.white60),
                          children: [
                            TextSpan(
                              text: 'Log In',
                              style: TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 700.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
