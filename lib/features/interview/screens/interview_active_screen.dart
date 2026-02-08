import 'dart:async';
import 'dart:convert';
import 'package:ai_interviewer/core/services/firestore_service.dart';
import 'package:ai_interviewer/core/services/gemini_service.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/interview/models/interview_exchange.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart';

class InterviewActiveScreen extends StatefulWidget {
  final String interviewId;
  final String companyName;
  final String role;
  final CameraDescription camera;
  final List<String> questions;

  const InterviewActiveScreen({
    super.key,
    required this.interviewId,
    required this.companyName,
    required this.role,
    required this.camera,
    required this.questions,
  });

  @override
  State<InterviewActiveScreen> createState() => _InterviewActiveScreenState();
}

class _InterviewActiveScreenState extends State<InterviewActiveScreen> {
  // Camera & Video
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  late VideoPlayerController _avatarController;
  bool _isAvatarInitialized = false;
  bool _isCameraOff = false;

  // Services
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final GeminiService _geminiService = GeminiService();

  // State
  int _currentQuestionIndex = 0;
  List<InterviewExchange> _exchanges = [];
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _isProcessing = false;
  String _currentAnswer = '';
  String _statusText = 'Initializing...';
  
  // Timer
  Timer? _timer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initAvatar();
    _startTimer();
    _initSpeechAndTTS();
  }

  Future<void> _initSpeechAndTTS() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);

    bool available = await _speech.initialize(
      onStatus: (status) => debugPrint('STT Status: $status'),
      onError: (error) => debugPrint('STT Error: $error'),
    );

    if (available && mounted) {
      // Start the interview after a short delay
      Future.delayed(const Duration(seconds: 1), _askNextQuestion);
    } else {
      setState(() => _statusText = "Speech recognition unavailable");
    }
  }

  void _initCamera() {
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false, // We use speech_to_text for audio
    );
    _initializeControllerFuture = _cameraController.initialize();
  }

  void _initAvatar() {
    _avatarController = VideoPlayerController.asset('assets/videos/avatar_video.mp4')
      ..initialize().then((_) {
        setState(() => _isAvatarInitialized = true);
        _avatarController.setLooping(true);
        _avatarController.pause();
      });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  String _formatTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _askNextQuestion() async {
    if (_currentQuestionIndex >= widget.questions.length) {
      _endInterview();
      return;
    }

    final question = widget.questions[_currentQuestionIndex];
    setState(() {
      _statusText = "Interviewer is speaking...";
      _isSpeaking = true;
      _avatarController.play(); // Animate avatar
    });

    await _flutterTts.speak(question);
    await _flutterTts.awaitSpeakCompletion(true);

    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _avatarController.pause();
        _statusText = "Preparing to listen...";
      });
      // Short delay to ensure TTS audio focus is released
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
         _statusText = "Listening...";
         _isListening = true;
      });
      _startListening();
    }
  }

  void _startListening() async {
    // Double check permissions (paranoid check)
    // var status = await Permission.microphone.status;
    // if (!status.isGranted) { ... } 
    
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _currentAnswer = result.recognizedWords;
          if (result.finalResult) {
             // Optional: Auto-submit on final result? 
             // For now let's keep it manual or timeout based
          }
        });
      },
      localeId: "en_US",
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      onSoundLevelChange: (level) {
         // Visualization hook
      },
      cancelOnError: true,
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> _stopListeningAndProcess() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _statusText = "Analyzing answer...";
    });

    if (_currentAnswer.trim().isEmpty) {
      _currentAnswer = "No answer provided.";
    }

    // 1. Evaluate with Gemini
    final currentQuestion = widget.questions[_currentQuestionIndex];
    final evaluation = await _geminiService.evaluateAnswer(
      currentQuestion,
      _currentAnswer,
      widget.role,
    );

    String feedback = "Thank you.";
    try {
        final Map<String, dynamic> jsonFeedback = jsonDecode(evaluation['feedback'] ?? '{}');
        feedback = jsonFeedback['feedback'] ?? "Thank you.";
    } catch(e) {
        feedback = evaluation['feedback'] ?? "Thank you.";
    }
    
    // Store Exchange
    final exchange = InterviewExchange(
      question: currentQuestion,
      answer: _currentAnswer,
      feedback: feedback,
      timestamp: DateTime.now(),
    );
    _exchanges.add(exchange);

    // Save progress to Firestore (incremental save)
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user != null) {
        // Ideally we append to the array, but for now let's just update the interview doc
        // Actually, 'updateInterviewQuestions' was for storing questions. 
        // We might need a new method 'saveInterviewExchange' in FirestoreService, but for MVP 
        // skipping incremental cloud save to keep it simple, will save all at end.
    }

    // Speak Feedback? 
    // Usually in an interview, feedback isn't given immediately unless it's a mock.
    // Let's have the AI say something brief or just move on. 
    // For this app, maybe just "Okay, moving on." or a short comment if generated.
    
    // Move to next
    setState(() {
      _isProcessing = false;
      _currentAnswer = '';
      _currentQuestionIndex++;
    });

    _askNextQuestion();
  }
  
  Future<void> _endInterview() async {
    _timer?.cancel();
    setState(() => _statusText = "Interview Complete");
    
    // Save full session
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user != null) {
       try {
         await FirestoreService().updateInterviewExchanges(
           user.uid,
           widget.interviewId,
           _exchanges.map((e) => e.toMap()).toList(),
         );
         debugPrint("Interview saved successfully!");
       } catch (e) {
         debugPrint("Error saving interview: $e");
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to save interview results")),
            );
         }
       }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Interview Completed', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Great job! Your responses have been recorded.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to home
            },
            child: const Text('Return Home', style: TextStyle(color: Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCamera() async {
    if (_isCameraOff) {
      await _cameraController.resumePreview();
    } else {
      await _cameraController.pausePreview();
    }
    setState(() => _isCameraOff = !_isCameraOff);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController.dispose();
    _avatarController.dispose();
    _flutterTts.stop();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // TOP HALF: Avatar (AI)
            Expanded(
              flex: 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                   Container(color: Colors.black),
                   if (_isAvatarInitialized)
                      AspectRatio(
                        aspectRatio: _avatarController.value.aspectRatio,
                        child: VideoPlayer(_avatarController),
                      ),
                   
                   // Status Overlay
                   Positioned(
                     top: 16,
                     left: 16,
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                       decoration: BoxDecoration(
                         color: Colors.black54,
                         borderRadius: BorderRadius.circular(20),
                       ),
                       child: Text(
                         _statusText,
                         style: const TextStyle(color: Colors.white, fontSize: 12),
                       ),
                     ),
                   ),

                   // Timer
                   Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, color: Colors.redAccent, size: 8),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(_secondsElapsed),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // MIDDLE: Transcript / Question
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF0F172A),
              child: Column(
                children: [
                   Text(
                     _currentQuestionIndex < widget.questions.length 
                        ? widget.questions[_currentQuestionIndex]
                        : "Wrapping up...",
                     style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                     textAlign: TextAlign.center,
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                   ),
                   const Spacer(),
                   Text(
                     _currentAnswer.isEmpty ? "..." : _currentAnswer,
                     style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                     textAlign: TextAlign.center,
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                   ),
                ],
              ),
            ),

            // BOTTOM HALF: Candidate Camera
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done && !_isCameraOff) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final scale = 1 / (_cameraController.value.aspectRatio * constraints.maxHeight / constraints.maxWidth);
                            return ClipRect(
                              child: Transform.scale(
                                scale: scale,
                                child: Center(
                                  child: CameraPreview(_cameraController),
                                ),
                              ),
                            );
                          },
                        );
                      } else {
                        return Container(
                            color: Colors.black, 
                            child: const Center(child: Icon(Icons.videocam_off, color: Colors.white24))
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // FOOTER: Controls
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              color: const Color(0xFF0F172A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Submit Answer / Stop Listening
                  if (_isListening)
                    ElevatedButton.icon(
                      onPressed: _stopListeningAndProcess,
                      icon: const Icon(Icons.check),
                      label: const Text("Done Speaking"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                      ),
                    )
                  else if (_isProcessing)
                     const CircularProgressIndicator(color: Colors.white)
                  else
                     const SizedBox(height: 48), // Spacer to keep height

                  // Camera Toggle
                  IconButton(
                    onPressed: _toggleCamera,
                    icon: Icon(_isCameraOff ? Icons.videocam_off : Icons.videocam),
                    color: Colors.white,
                  ),

                  // Exit
                  IconButton(
                    onPressed: () => Navigator.pop(context), 
                    icon: const Icon(Icons.close),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
