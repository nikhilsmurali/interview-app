import 'dart:async';
import 'package:ai_interviewer/core/services/gemini_service.dart';
import 'package:ai_interviewer/features/interview/screens/interview_active_screen.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ai_interviewer/core/services/firestore_service.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:provider/provider.dart';

class InterviewPrepScreen extends StatefulWidget {
  final String interviewId;
  final String companyName;
  final String role;

  const InterviewPrepScreen({
    super.key,
    required this.interviewId,
    required this.companyName,
    required this.role,
  });

  @override
  State<InterviewPrepScreen> createState() => _InterviewPrepScreenState();
}

class _InterviewPrepScreenState extends State<InterviewPrepScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  bool _isGeneratingQuestions = true;
  int _countdown = 5;
  Timer? _countdownTimer;
  List<String> _questions = [];

  @override
  void initState() {
    super.initState();
    _initializePrep();
  }

  Future<void> _initializePrep() async {
    // 1. Request Permissions
    await [Permission.camera, Permission.microphone].request();

    // 2. Initialize Camera
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Use front camera if available
        final frontCamera = _cameras!.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );
        
        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false, // No audio needed for preview checks
        );

        await _cameraController!.initialize();
        if (mounted) setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }

    // 3. Generate Questions (Gemini)
    try {
      final service = GeminiService();
      _questions = await service.generateInterviewQuestions(
        widget.companyName,
        widget.role,
      );
      debugPrint("Generated Questions: $_questions");

      // Store in Firestore
      if (mounted) {
        final user = Provider.of<AuthService>(context, listen: false).user;
        if (user != null) {
          await FirestoreService().updateInterviewQuestions(
            user.uid,
            widget.interviewId,
            _questions,
          );
           debugPrint("Questions saved to Firestore!");
        }
      }

    } catch (e) {
      debugPrint("Error generating/saving questions: $e");
    } finally {
      if (mounted) setState(() => _isGeneratingQuestions = false);
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _countdownTimer?.cancel();
          _navigateToInterview();
        }
      });
    });
  }

  void _navigateToInterview() {
    if (!mounted) return;
    
    // We dispose this controller as the next screen creates its own with audio enabled
    // Optimally we could pass it, but changing capture mode might require re-init
    _cameraController?.dispose(); 
    _cameraController = null;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InterviewActiveScreen(
          companyName: widget.companyName,
          role: widget.role,
          camera: _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras!.first,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            
            Text(
              'Hardware Check',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Setting up your studio...',
              style: TextStyle(color: Colors.white54),
            ),

            const SizedBox(height: 40),

            // Camera Preview Circle
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6366F1), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                ),
                clipBehavior: Clip.hardEdge,
                child: _isCameraReady && _cameraController != null
                    ? CameraPreview(_cameraController!)
                    : const Center(
                        child: Icon(Icons.camera_alt, color: Colors.white24, size: 50),
                      ),
              ),
            ),

            const Spacer(),

            // Status Area
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                   _buildStatusRow(
                    icon: Icons.videocam,
                    label: 'Camera Access',
                    isReady: _isCameraReady,
                  ),
                  const SizedBox(height: 16),
                   _buildStatusRow(
                    icon: Icons.mic,
                    label: 'Microphone Access',
                    isReady: _isCameraReady, // Assuming mic perms granted with cam
                  ),
                  const SizedBox(height: 16),
                   _buildStatusRow(
                    icon: Icons.psychology,
                    label: 'AI Interviewer',
                    isLoading: _isGeneratingQuestions,
                    isReady: !_isGeneratingQuestions,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Countdown or Loading
            if (!_isGeneratingQuestions)
               Column(
                children: [
                   Text(
                    'Starting in',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  Text(
                    '$_countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate(key: ValueKey(_countdown)).scale(
                        duration: 300.ms,
                        curve: Curves.easeOutBack,
                        begin: const Offset(0.5, 0.5),
                      ),
                ],
              )
            else
               const CircularProgressIndicator(color: Color(0xFF6366F1)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required String label,
    bool isReady = false,
    bool isLoading = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(width: 16),
        Text(label, style: const TextStyle(color: Colors.white)),
        const Spacer(),
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
          )
        else if (isReady)
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
        else
          const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
      ],
    );
  }
}
