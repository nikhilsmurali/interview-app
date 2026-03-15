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
    this.difficulty = 'Medium',
  });

  final String difficulty;

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
  
  // Follow-up tracking
  final Set<String> _followUpQuestions = {};
  int _followUpsForCurrentMainQuestion = 0;
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
    if (!mounted) return;

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

    _statusText = "Interviewer is speaking...";
    try {
      await _flutterTts.speak(question);
    } catch (ttsErr) {
      debugPrint("TTS Failed: $ttsErr");
    }

    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _avatarController.pause();
        _statusText = "Preparing to listen...";
      });
      // Short delay to ensure TTS audio focus is released
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;

      setState(() {
         _statusText = "Listening...";
         _isListening = true;
      });
      _startListening();
    }
  }

  void _startListening() async {
    if (!mounted) return;

    // Stop any existing session just in case
    if (_speech.isListening) {
      await _speech.stop();
    }
    
    if (!mounted) return;
    
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

      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _avatarController.pause();
        _statusText = "Listening...";
        _isListening = true;
      });
      _startListening();
      return; // Do not increment question index or save exchange
    }

    // 1. Evaluate with Groq
    final currentQuestion = widget.questions[_currentQuestionIndex];
    final evaluation = await _openAIService.evaluateAnswer(
      currentQuestion,
      _currentAnswer,
      widget.role,
      widget.difficulty,
    );

    if (!mounted) return;

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
      bool isCurrentAFollowUp = _followUpQuestions.contains(currentQuestion);
      
      bool allowFollowUp = true;
      if (widget.difficulty == 'Easy') {
        // For easy mode, if the current question is already a follow-up, don't ask more.
        // Or if we want to restrict "total sub questions asked to 1", maybe it means only 1 per main question.
        if (isCurrentAFollowUp) {
          allowFollowUp = false;
        }
      }

      if (allowFollowUp) {
        _followUpQuestions.add(followUp);
        widget.questions.insert(_currentQuestionIndex + 1, followUp);
      }
    }

    // Speak Feedback
    setState(() {
      _statusText = "Providing feedback...";
      _isSpeaking = true;
      _avatarController.play(); 
    });

    _statusText = "Providing feedback...";
    try {
      await _flutterTts.speak(feedback);
    } catch (ttsErr) {
      debugPrint("TTS Feedback Failed: $ttsErr");
    }

    if (!mounted) return;
    
    // Move to next
    setState(() {
      _isProcessing = false;
      _currentAnswer = '';
      _currentQuestionIndex++;
    });

    _askNextQuestion();
  }

  Future<void> _skipQuestion() async {
    if (_isProcessing || _isSpeaking) return;

    await _speech.stop();
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _statusText = "Skipping question...";
    });

    // 1. Store a skipped exchange so it appears in the report
    final currentQuestion = widget.questions[_currentQuestionIndex];
    final exchange = InterviewExchange(
      question: currentQuestion,
      answer: "Candidate skipped this question.",
      feedback: "No problem. Let's move on to something else.",
      rating: 0,
      timestamp: DateTime.now(),
    );
    _exchanges.add(exchange);

    // 2. Short acknowledgment from AI
    setState(() {
      _isSpeaking = true;
      _avatarController.play();
    });

    try {
      await _flutterTts.speak("No problem. Let's move to the next question.");
    } catch (e) {
      debugPrint("TTS Failed: $e");
    }

    if (!mounted) return;

    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _avatarController.pause();
        _isProcessing = false;
        _currentAnswer = '';
        _currentQuestionIndex++;
      });
      _askNextQuestion();
    }
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
            // TOP: AI Avatar (Interviewer)
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                   if (_isAvatarInitialized)
                      Center(
                        child: AspectRatio(
                          aspectRatio: _avatarController.value.aspectRatio,
                          child: VideoPlayer(_avatarController),
                        ),
                      )
                   else
                      Container(color: Colors.black),
                   
                   // AI Caption Overlay
                   Positioned(
                     bottom: 20,
                     left: 20,
                     right: 20,
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                       decoration: BoxDecoration(
                         color: Colors.black.withOpacity(0.6),
                         borderRadius: BorderRadius.circular(12),
                       ),
                       child: Text(
                         _currentQuestionIndex < widget.questions.length 
                            ? widget.questions[_currentQuestionIndex]
                            : "Interview concluding...",
                         style: const TextStyle(
                           color: Colors.white, 
                           fontWeight: FontWeight.w500,
                           fontSize: 14,
                         ),
                         textAlign: TextAlign.center,
                       ),
                     ),
                   ),

                   // Status Badge (Top Left)
                   Positioned(
                     top: 16,
                     left: 16,
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                       decoration: BoxDecoration(
                         color: const Color(0xFFFF5A00).withOpacity(0.8),
                         borderRadius: BorderRadius.circular(20),
                       ),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           const Icon(Icons.psychology, color: Colors.white, size: 14),
                           const SizedBox(width: 6),
                           Text(
                             _statusText,
                             style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                           ),
                         ],
                       ),
                     ),
                   ),
                ],
              ),
            ),

            // Divider line
            Container(height: 1, color: Colors.white24),

            // BOTTOM: Candidate (User)
            Expanded(
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
                            color: const Color(0xFF1A1A1A), 
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.videocam_off, color: Colors.white.withOpacity(0.2), size: 48),
                                  const SizedBox(height: 12),
                                  Text("Camera Off", style: TextStyle(color: Colors.white.withOpacity(0.2))),
                                ],
                              )
                            )
                        );
                      }
                    },
                  ),

                  // User Transcript Caption Overlay
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: AnimatedOpacity(
                      opacity: _currentAnswer.isEmpty ? 0 : 1,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5A00).withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _currentAnswer,
                          style: const TextStyle(
                            color: Colors.white, 
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                  // Timer (Top Right)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
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
                              fontSize: 12,
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

            // FOOTER: Redesigned Controls
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              color: Colors.black,
              child: Row(
                children: [
                  // Main Actions Expanded
                  Expanded(
                    child: _isListening
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _skipQuestion,
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  label: const Text("Don't Know", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _stopListeningAndProcess,
                                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                                  label: const Text("Done Speaking", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF5A00),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _isProcessing
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5A00)),
                                ),
                              )
                            : Container(
                                height: 48,
                                alignment: Alignment.centerLeft,
                                child: const Text("Waiting...", style: TextStyle(color: Colors.white24)),
                              ),
                  ),

                  const SizedBox(width: 12),

                  // More (Three Dots) Menu
                  Theme(
                    data: Theme.of(context).copyWith(
                      cardColor: const Color(0xFF1E1E1E),
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                      onSelected: (value) {
                        switch (value) {
                          case 'camera': _toggleCamera(); break;
                          case 'mic': _startListening(); break;
                          case 'end': Navigator.pop(context); break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'camera',
                          child: Row(
                            children: [
                              Icon(_isCameraOff ? Icons.videocam : Icons.videocam_off, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Text(_isCameraOff ? "Turn Camera On" : "Turn Camera Off", style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'mic',
                          child: Row(
                            children: [
                              const Icon(Icons.mic, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              const Text("Reset Microphone", style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 1),
                        PopupMenuItem(
                          value: 'end',
                          child: const Row(
                            children: [
                              Icon(Icons.call_end, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 12),
                              Text("End Interview", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
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
