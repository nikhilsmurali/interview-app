import 'package:ai_interviewer/core/services/firestore_service.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/auth/widgets/auth_text_field.dart';
import 'package:ai_interviewer/features/auth/widgets/primary_button.dart';
import 'package:ai_interviewer/features/home/models/interview_session.dart';
import 'package:ai_interviewer/features/interview/screens/interview_prep_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class StartInterviewScreen extends StatefulWidget {
  const StartInterviewScreen({super.key});

  @override
  State<StartInterviewScreen> createState() => _StartInterviewScreenState();
}

class _StartInterviewScreenState extends State<StartInterviewScreen> {
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  double _yearsOfExperience = 0;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _companies = [
    {'name': 'Google', 'logo': Icons.g_mobiledata}, // Placeholder icons
    {'name': 'Meta', 'logo': Icons.facebook},
    {'name': 'Amazon', 'logo': Icons.shopping_cart},
    {'name': 'Netflix', 'logo': Icons.movie},
    {'name': 'Apple', 'logo': Icons.apple},
    {'name': 'Microsoft', 'logo': Icons.window},
    {'name': 'Spotify', 'logo': Icons.music_note},
    {'name': 'Airbnb', 'logo': Icons.house},
  ];

  @override
  void dispose() {
    _companyController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _startInterview() async {
    if (_companyController.text.isEmpty || _roleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter company and role')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Provider.of<AuthService>(context, listen: false).user;
      if (user == null) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      final session = InterviewSession(
        id: const Uuid().v4(), // Need uuid package, or generate random string
        userId: user.uid,
        targetCompany: _companyController.text,
        targetRole: _roleController.text,
        yearsOfExperience: _yearsOfExperience,
        createdAt: DateTime.now(),
        status: 'initiated',
      );

      await FirestoreService().startNewInterview(session);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interview Started!')),
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InterviewPrepScreen(
              interviewId: session.id,
              companyName: _companyController.text,
              role: _roleController.text,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Interview', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Target Company',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            
            // Moving Company List (Marquee effect)
             SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                 // Simple infinite scroll simulation by large count or repeated items
                 // For now, standard list
                itemCount: _companies.length,
                itemBuilder: (context, index) {
                  final company = _companies[index];
                  return GestureDetector(
                    onTap: () {
                      _companyController.text = company['name'];
                      setState(() {});
                    },
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: _companyController.text == company['name']
                            ? Border.all(color: const Color(0xFF6366F1), width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(company['logo'], color: Colors.white70, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            company['name'],
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 16),
            const Text(
              'Or enter manually:',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            AuthTextField(
              controller: _companyController,
              hintText: 'Company Name',
              icon: Icons.business,
            ),

            const SizedBox(height: 32),

            Text(
              'Target Role',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _roleController,
              hintText: 'e.g. Senior Flutter Developer',
              icon: Icons.work_outline,
            ),

            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Experience',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                Text(
                  '${_yearsOfExperience.toInt()} Years',
                   style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _yearsOfExperience,
              min: 0,
              max: 20,
              divisions: 20,
              activeColor: const Color(0xFF6366F1),
              inactiveColor: Colors.white24,
              onChanged: (val) => setState(() => _yearsOfExperience = val),
            ),

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : PrimaryButton(
                      text: 'Start Interview',
                      onPressed: _startInterview,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
