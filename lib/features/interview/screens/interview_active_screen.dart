import 'dart:async';
import 'dart:convert';
import 'package:ai_interviewer/core/services/firestore_service.dart';
import 'package:ai_interviewer/core/services/openai_service.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/interview/models/interview_exchange.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart';
import 'package:ai_interviewer/features/home/screens/interview_report_screen.dart';
import 'package:ai_interviewer/features/home/models/interview_session.dart';

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
  final OpenAIService _openAIService = OpenAIService();

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
    try {
      await _flutterTts.setLanguage("en-US");
    } catch (e) {
      debugPrint("Could not set language, using device default");
    }
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0); 
    // This MUST be set once at initialization.
    await _flutterTts.awaitSpeakCompletion(true);

    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('STT Status: $status');
        if (status == 'done' && mounted && _isListening) {
           // If it stops listening prematurely, we might want to restart or just wait for the user to hit Done
        }
      },
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

    try {
      // Timeout prevents infinite loop if the device's TTS engine is broken or silent
      await _flutterTts.speak(question).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint("TTS Timeout or Error: $e");
    }

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
    // Stop any existing session just in case
    if (_speech.isListening) {
      await _speech.stop();
    }
    
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _currentAnswer = result.recognizedWords;
          });
        }
      },
      localeId: "en_US",
      listenFor: const Duration(seconds: 120),
      // No pauseFor allows the user to take a breath without it shutting off
      partialResults: true,
      cancelOnError: false, // very important on Android
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

    if (_currentAnswer.trim().isEmpty || _currentAnswer.trim().length < 8) {
      // Short-circuit: The user didn't say anything meaningful, ask them to repeat
      setState(() {
        _statusText = "Asking to repeat...";
        _isSpeaking = true;
      });
      _avatarController.play();

      try {
        await _flutterTts.speak("I didn't quite catch that. Could you please answer clearly and loudly?").timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint("Error speaking feedback: $e");
      }

      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _avatarController.pause();
          _statusText = "Listening...";
          _isListening = true;
        });
        _startListening();
      }
      return; // Do not increment question index or save exchange
    }

    // 1. Evaluate with Groq
    final currentQuestion = widget.questions[_currentQuestionIndex];
    final evaluation = await _openAIService.evaluateAnswer(
      currentQuestion,
      _currentAnswer,
      widget.role,
    );

    String feedback = evaluation['feedback'] ?? "Thank you.";
    int rating = 5;
    if (evaluation['rating'] != null) {
      if (evaluation['rating'] is int) {
        rating = evaluation['rating'];
      } else if (evaluation['rating'] is String) {
        rating = int.tryParse(evaluation['rating']) ?? 5;
      }
    }
    
    // Store Exchange
    final exchange = InterviewExchange(
      question: currentQuestion,
      answer: _currentAnswer,
      feedback: feedback,
      rating: rating,
      timestamp: DateTime.now(),
    );
    _exchanges.add(exchange);

    // Dynamic Follow-up
    String? followUp = evaluation['followUp'];
    if (followUp != null && followUp.trim().isNotEmpty && followUp.toLowerCase() != 'null') {
      widget.questions.insert(_currentQuestionIndex + 1, followUp);
    }

    // Speak Feedback
    setState(() {
      _statusText = "Providing feedback...";
      _isSpeaking = true;
      _avatarController.play(); 
    });

    try {
      // Make sure speech doesn't hang forever
      await _flutterTts.speak(feedback).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint("Error speaking feedback: $e");
    }

    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _avatarController.pause();
      });
    }
    
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

    if (mounted) {
      // Calculate aggregate score out of 10
      double aggregateScore = 0;
      if (_exchanges.isNotEmpty) {
        int totalRating = _exchanges.fold(0, (sum, e) => sum + e.rating);
        aggregateScore = totalRating / _exchanges.length;
      }

      final session = InterviewSession(
        id: widget.interviewId,
        userId: user?.uid ?? '',
        targetCompany: widget.companyName,
        targetRole: widget.role,
        yearsOfExperience: 0,
        status: 'completed',
        createdAt: DateTime.now(),
        exchanges: _exchanges,
        overallScore: double.parse(aggregateScore.toStringAsFixed(1)),
        feedbackSummary: "Interview completed. Score: ${aggregateScore.toStringAsFixed(1)}/10",
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InterviewReportScreen(session: session),
        ),
      );
    }
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
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                             // Restart Mic manually if stuck
                             _startListening();
                          },
                          icon: const Icon(Icons.mic),
                          label: const Text("Reset Mic"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _stopListeningAndProcess,
                          icon: const Icon(Icons.check),
                          label: const Text("Done Speaking"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
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
