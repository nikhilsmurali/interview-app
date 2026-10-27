import 'package:ai_interviewer/core/services/firestore_service.dart';
import 'package:ai_interviewer/core/services/resume_parser_service.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/auth/widgets/auth_text_field.dart';
import 'package:ai_interviewer/features/auth/widgets/primary_button.dart';
import 'package:ai_interviewer/features/home/models/interview_session.dart';
import 'package:ai_interviewer/features/interview/screens/interview_prep_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
  final TextEditingController _jobDescriptionController = TextEditingController();
  double _yearsOfExperience = 0;
  String _difficulty = 'Medium';
  final List<String> _difficulties = ['Easy', 'Medium', 'Hard'];
  bool _isLoading = false;

  // Resume file state
  String? _uploadedFileName;
  int? _uploadedFileSize;
  bool _isParsingResume = false;
  int _parsedWordCount = 0;
  bool _showRawResumeEditor = false;

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
    _jobDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAndParseResume() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'txt', 'md'],
      );

      if (files.isEmpty) return;

      setState(() => _isParsingResume = true);

      final file = files.first;
      final parsedText = await ResumeParserService.parseFile(file);
      final words = parsedText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      final fileSize = file.lengthSync() ?? (await file.length()) ?? 0;

      setState(() {
        _uploadedFileName = file.name;
        _uploadedFileSize = fileSize;
        _resumeController.text = parsedText;
        _parsedWordCount = words;
        _isParsingResume = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Extracted $words words from ${file.name}!'),
            backgroundColor: const Color(0xFF1B8A5A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isParsingResume = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not parse resume: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _removeResume() {
    setState(() {
      _uploadedFileName = null;
      _uploadedFileSize = null;
      _resumeController.clear();
      _parsedWordCount = 0;
      _showRawResumeEditor = false;
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
              jobDescription: _jobDescriptionController.text,
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

            // SECTION: Resume Upload & Parsing
            Row(
              children: [
                const Icon(Icons.badge_outlined, color: Color(0xFFFF5A00), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Candidate Resume / CV',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A00).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFF5A00).withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Auto ATS Parse',
                    style: TextStyle(color: Color(0xFFFF8A00), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Upload your resume in PDF or DOCX format. The AI automatically extracts your projects, skills, and background.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55), fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Dropzone / File Card
            if (_isParsingResume)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF5A00).withValues(alpha: 0.5)),
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFFFF5A00)),
                    SizedBox(height: 16),
                    Text(
                      'Extracting text & skills from resume...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              )
            else if (_uploadedFileName != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1B8A5A).withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5A00).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _uploadedFileName!.endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                            color: const Color(0xFFFF8A00),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _uploadedFileName!,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatFileSize(_uploadedFileSize ?? 0),
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B8A5A).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF1B8A5A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF2ECC71), size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '$_parsedWordCount words',
                                style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() => _showRawResumeEditor = !_showRawResumeEditor),
                          icon: Icon(_showRawResumeEditor ? Icons.expand_less : Icons.expand_more, size: 16),
                          label: Text(_showRawResumeEditor ? 'Hide Parsed Text' : 'View / Edit Parsed Text', style: const TextStyle(fontSize: 12)),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _pickAndParseResume,
                          icon: const Icon(Icons.sync_rounded, size: 15),
                          label: const Text('Replace', style: TextStyle(fontSize: 12)),
                        ),
                        IconButton(
                          onPressed: _removeResume,
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          tooltip: 'Remove Resume',
                        ),
                      ],
                    ),
                    if (_showRawResumeEditor) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _resumeController,
                        maxLines: 6,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Parsed resume text...',
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.3),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              Column(
                children: [
                  InkWell(
                    onTap: _pickAndParseResume,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5A00).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFFFF5A00), size: 32),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Click to Upload Resume (PDF / DOCX)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Supports .pdf, .docx, .doc, or .txt (Max 15MB)',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showRawResumeEditor = !_showRawResumeEditor),
                      icon: const Icon(Icons.text_fields_rounded, size: 14),
                      label: Text(
                        _showRawResumeEditor ? 'Hide manual text box' : 'Or paste resume text manually',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  if (_showRawResumeEditor) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: _resumeController,
                      maxLines: 5,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Paste your raw resume text here...',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

            const SizedBox(height: 32),

            // SECTION: Job Description (JD) & Gap Analysis
            Row(
              children: [
                const Icon(Icons.troubleshoot_rounded, color: Color(0xFFFF5A00), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Target Job Description (JD)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'Gap Analysis',
                    style: TextStyle(color: Colors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Paste the job description or role requirements. The AI will compare your resume against the JD and ask targeted questions on your claimed skills or detected gap areas.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55), fontSize: 12),
            ),
            const SizedBox(height: 12),

            // Gap Analysis indicator banner when both are active
            if (_resumeController.text.trim().isNotEmpty && _jobDescriptionController.text.trim().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF5A00).withValues(alpha: 0.15),
                      Colors.blueAccent.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF5A00).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFFFF8A00), size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Gap Analysis Activated: AI will probe unlisted skills and deep-dive into your resume claims!',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            TextField(
              controller: _jobDescriptionController,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Paste target Job Description (e.g. Responsibilities: architect scalable Flutter apps, lead code reviews; Qualifications: 3+ years Dart, BLoC, CI/CD, REST APIs)...',
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
