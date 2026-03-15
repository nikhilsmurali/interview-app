import 'package:ai_interviewer/features/auth/widgets/auth_text_field.dart';
import 'package:ai_interviewer/features/auth/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/core/services/firestore_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).colorScheme.surface,
                ],
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
                    'Welcome Back',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ).animate().fadeIn().moveX(begin: -20, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue your progress',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 48),
                  
                  AuthTextField(
                    hintText: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ).animate().fadeIn(delay: 300.ms).moveY(begin: 20, end: 0),
                  const SizedBox(height: 16),
                  
                  AuthTextField(
                    hintText: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ).animate().fadeIn(delay: 400.ms).moveY(begin: 20, end: 0),
                  
                   Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Forgot Password
                      },
                       child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFFFF5A00))),
                    ),
                  ).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: 'Log In',
                      onPressed: () async {
                        // TODO: Add Email/Password Logic
                      },
                    ),
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 16),
                  
                  Center(
                    child: Text(
                      'OR',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                    ),
                  ).animate().fadeIn(delay: 650.ms),
                  
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: FaIcon(FontAwesomeIcons.google, color: Theme.of(context).colorScheme.onSurface),
                      label: Text(
                        'Sign in with Google',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () async {
                        final authService = Provider.of<AuthService>(context, listen: false);
                        final userCredential = await authService.signInWithGoogle();
                        if (context.mounted && userCredential != null) {
                           // check if preferences exist
                           final profile = await FirestoreService().getProfile(userCredential.user!.uid);
                           if (context.mounted) {
                             if (profile == null || profile.preferences == null) {
                               Navigator.pushReplacementNamed(context, '/preferences');
                             } else {
                               Navigator.of(context).popUntil((route) => route.isFirst);
                             }
                           }
                        }
                      },
                    ),
                  ).animate().fadeIn(delay: 700.ms),
                  Center(
                    child: TextButton(
                      onPressed: () {
                         Navigator.pushReplacementNamed(context, '/signup');
                      },
                      child: RichText(
                        text: TextSpan(
                          text: 'Don\'t have an account? ',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          children: const [
                             TextSpan(
                              text: 'Sign Up',
                              style: TextStyle(
                                color: Color(0xFFFF5A00),
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
