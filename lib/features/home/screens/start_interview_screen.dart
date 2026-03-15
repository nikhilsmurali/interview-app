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
  final TextEditingController _resumeController = TextEditingController();
  double _yearsOfExperience = 0;
  String _difficulty = 'Medium';
  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];
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
    _resumeController.dispose();
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
        difficulty: _difficulty,
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
              resumeText: _resumeController.text,
              difficulty: _difficulty,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('New Interview', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Target Company',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
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
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: _companyController.text == company['name']
                            ? Border.all(color: const Color(0xFFFF5A00), width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(company['logo'], color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 32),
                          const SizedBox(height: 8),
                          Text(
                            company['name'],
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
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
            Text(
              'Or enter manually:',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                ),
                Text(
                  '${_yearsOfExperience.toInt()} Years',
                   style: const TextStyle(color: Color(0xFFFF5A00), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _yearsOfExperience,
              min: 0,
              max: 20,
              divisions: 20,
              activeColor: const Color(0xFFFF5A00),
              inactiveColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              onChanged: (val) => setState(() => _yearsOfExperience = val),
            ),
            
            const SizedBox(height: 32),
            Text(
              'Difficulty Mode',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _difficulties.map((level) {
                final isSelected = _difficulty == level;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _difficulty = level),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFF5A00) : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? null : Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
                      ),
                      child: Center(
                        child: Text(
                          level,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),
            Text(
              'Resume / CV Text (Optional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Paste your resume text to get highly personalized interview questions based on your past projects!',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _resumeController,
              maxLines: 6,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Paste your resume content here...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5A00)))
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
