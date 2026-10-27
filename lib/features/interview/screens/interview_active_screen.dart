import 'dart:async';
import 'package:ai_interviewer/core/services/eleven_labs_service.dart';
import 'package:ai_interviewer/core/services/firestore_service.dart';
import 'package:ai_interviewer/core/services/openai_service.dart';
import 'package:flutter/foundation.dart';
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
import 'package:ai_interviewer/core/services/speech_metrics_analyzer.dart';
import 'package:ai_interviewer/features/interview/widgets/body_language_hud.dart';
import 'package:ai_interviewer/features/interview/widgets/live_audio_waveform.dart';
import 'package:ai_interviewer/features/interview/widgets/live_code_editor_sheet.dart';
import 'package:ai_interviewer/features/interview/widgets/system_design_whiteboard_sheet.dart';

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
  final ElevenLabsService _elevenLabsService = ElevenLabsService();

  // State
  int _currentQuestionIndex = 0;
  List<InterviewExchange> _exchanges = [];
  bool _isSpeaking = false;
  bool _isListening = false;
  bool _isProcessing = false;
  String _currentAnswer = '';
  String _statusText = 'Initializing...';
  String _introductoryText = '';
  String _conclusionText = '';
  bool _isIntroductoryPhase = true;
  bool _isConclusionPhase = false;
  String? _transitionAnnouncement;
  
  // Follow-up tracking
  final Set<String> _followUpQuestions = {};
  int _followUpsForCurrentMainQuestion = 0;
  Timer? _timer;
  int _secondsElapsed = 0;

  // Split-screen & speech metrics tracking
  String? _activeSplitTool; // 'code', 'whiteboard', or null
  int _totalCandidateSpeakingSeconds = 0;
  DateTime? _answeringStartTime;
  bool _useInstantDeviceVoice = false;

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
    // Web speechRate: 0.95 for responsive, natural cadence
    await _flutterTts.setSpeechRate(kIsWeb ? 0.95 : 0.5);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setVolume(1.0); 
    // This MUST be set once at initialization.
    await _flutterTts.awaitSpeakCompletion(true);

    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('STT Status: $status');
        // Auto-submit after candidate finishes speaking and silence is detected
        if (status == 'done' && mounted && _isListening && _currentAnswer.trim().length >= 8 && !_isProcessing) {
          _stopListeningAndProcess();
        }
      },
      onError: (error) {
        debugPrint('STT Error: $error');
        if (mounted && error.errorMsg.contains('not-allowed')) {
          setState(() {
            _statusText = "Microphone blocked in Chrome! Please allow mic access in URL bar.";
          });
        }
      },
    );

    if (available && mounted) {
      // Start with introduction
      Future.delayed(const Duration(seconds: 1), _doSelfIntroduction);
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
    _initializeControllerFuture = _cameraController.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((err) async {
      debugPrint("Camera initialize error in active screen: $err. Retrying...");
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      try {
        await _cameraController.dispose();
      } catch (_) {}

      try {
        final cams = await availableCameras();
        final selectedCam = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cams.isNotEmpty ? cams.first : widget.camera,
        );
        _cameraController = CameraController(
          selectedCam,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        _initializeControllerFuture = _cameraController.initialize();
        await _initializeControllerFuture;
        if (mounted) setState(() {});
      } catch (retryErr) {
        debugPrint("Camera retry error: $retryErr");
      }
    });
  }

  void _initAvatar() {
    _avatarController = VideoPlayerController.asset('assets/videos/avatar_video.mp4')
      ..initialize().then((_) {
        setState(() => _isAvatarInitialized = true);
        _avatarController.setLooping(true);
        _avatarController.setVolume(0.0); // MUTE avatar video to stop audio driver contention & lag
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

  Future<void> _speakText(String text) async {
    final cleanText = ElevenLabsService.sanitizeText(text);
    if (cleanText.isEmpty) return;

    try {
      await _elevenLabsService.stop();
    } catch (_) {}
    try {
      await _flutterTts.stop();
    } catch (_) {}

    // 1. Instant Local Device Voice (0ms network roundtrip latency)
    if (_useInstantDeviceVoice) {
      try {
        await _flutterTts.setVolume(1.0);
        await _flutterTts.setSpeechRate(kIsWeb ? 0.95 : 0.5);
        await _flutterTts.setPitch(1.0);
        await _flutterTts.speak(cleanText).timeout(const Duration(seconds: 15));
      } catch (ttsErr) {
        debugPrint("Local device TTS Error: $ttsErr");
      }
      return;
    }

    // 2. Try ElevenLabs for ultra-crisp studio voice with optimize_streaming_latency=3
    try {
      await _elevenLabsService.speak(cleanText).timeout(const Duration(seconds: 15));
      return;
    } catch (e) {
      debugPrint("ElevenLabs failed or timed out: $e. Falling back to device TTS.");
    }

    // 3. Fallback to FlutterTts
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(kIsWeb ? 0.95 : 0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.speak(cleanText).timeout(const Duration(seconds: 15));
    } catch (ttsErr) {
      debugPrint("TTS Fallback Failed: $ttsErr");
    }
  }

  Future<void> _doSelfIntroduction() async {
    if (!mounted) return;

    final user = Provider.of<AuthService>(context, listen: false).user;
    final userName = user?.displayName?.split(' ').first ?? 'candidate';
    
    _introductoryText = "Hi $userName, I am your AI interviewer today for the ${widget.role} position at ${widget.companyName}. Let's begin our session.";
    
    setState(() {
      _statusText = "Interviewer Introduction...";
      _isSpeaking = true;
      _avatarController.play();
    });

    try {
      await _speakText(_introductoryText);
    } catch (e) {
      debugPrint("Intro TTS Failed: $e");
    }

    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _avatarController.pause();
        _isIntroductoryPhase = false;
        _statusText = "Preparing...";
      });
      
      // Responsive transition before first question (100ms instead of 800ms)
      await Future.delayed(const Duration(milliseconds: 100));
      _askNextQuestion();
    }
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

    try {
      await _speakText(question);
    } catch (ttsErr) {
      debugPrint("TTS Failed: $ttsErr");
    }

    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _avatarController.pause();
        _statusText = "Preparing to listen...";
      });
      // Short transition to release audio focus (100ms instead of 500ms)
      await Future.delayed(const Duration(milliseconds: 100));
      
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
    
    _answeringStartTime = DateTime.now();

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
      pauseFor: const Duration(seconds: 3), // Auto-submits 3s after candidate finishes speaking
      partialResults: true,
      cancelOnError: false, // very important on Android
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> _stopListeningAndProcess() async {
    await _speech.stop();
    if (_answeringStartTime != null) {
      _totalCandidateSpeakingSeconds += DateTime.now().difference(_answeringStartTime!).inSeconds;
      _answeringStartTime = null;
    }
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
        await _speakText("I didn't quite catch that. Could you please answer clearly and loudly?");
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

    try {
      await _speakText(feedback);
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
    if (_isProcessing) return;

    try {
      await _speech.stop();
    } catch (_) {}
    try {
      await _elevenLabsService.stop();
    } catch (_) {}
    try {
      await _flutterTts.stop();
    } catch (_) {}

    if (!mounted) return;

    final currentQuestion = _currentQuestionIndex < widget.questions.length
        ? widget.questions[_currentQuestionIndex]
        : "Question";
    const skipFeedback = "That's completely okay. Let's move on to the next question.";

    // 1. Store a skipped exchange so it appears in the final scorecard
    final exchange = InterviewExchange(
      question: currentQuestion,
      answer: "Question skipped by candidate (Don't Know).",
      feedback: skipFeedback,
      rating: 0,
      timestamp: DateTime.now(),
    );
    _exchanges.add(exchange);

    // 2. Announce verbally and display on interviewer card
    setState(() {
      _isListening = false;
      _isSpeaking = true;
      _isProcessing = true;
      _transitionAnnouncement = skipFeedback;
      _statusText = "Moving to next question...";
    });
    _avatarController.play();

    try {
      await _speakText(skipFeedback);
    } catch (e) {
      debugPrint("Skip acknowledgment speech error: $e");
    }

    if (!mounted) return;

    // 3. Advance to the next question
    setState(() {
      _transitionAnnouncement = null;
      _isSpeaking = false;
      _avatarController.pause();
      _isProcessing = false;
      _currentAnswer = '';
      _currentQuestionIndex++;
    });

    _askNextQuestion();
  }

  void _showTextAnswerDialog() {
    final controller = TextEditingController(text: _currentAnswer);
    
    // Pause speech recognition while editing
    _speech.stop();
    setState(() {
      _isListening = false;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: Color(0xFFFF5A00), width: 2),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.keyboard_alt_rounded, color: Color(0xFFFF5A00), size: 22),
                        SizedBox(width: 8),
                        Text(
                          "Type / Edit Your Answer",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () {
                        Navigator.pop(modalContext);
                        _startListening();
                        setState(() => _isListening = true);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Review or edit what was captured, or type your complete answer below:",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLines: 5,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Type your answer here...",
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFF5A00)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(modalContext);
                          _startListening();
                          setState(() => _isListening = true);
                        },
                        icon: const Icon(Icons.mic, size: 18),
                        label: const Text("Use Voice"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final text = controller.text.trim();
                          Navigator.pop(modalContext);
                          if (text.isNotEmpty) {
                            setState(() {
                              _currentAnswer = text;
                            });
                            _stopListeningAndProcess();
                          }
                        },
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text("Submit", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5A00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openLiveCodeEditor({bool forceModal = false}) {
    final isWide = MediaQuery.of(context).size.width >= 850;
    if (isWide && !forceModal) {
      setState(() {
        _activeSplitTool = _activeSplitTool == 'code' ? null : 'code';
      });
      return;
    }

    final currentQ = _currentQuestionIndex < widget.questions.length
        ? widget.questions[_currentQuestionIndex]
        : '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => LiveCodeEditorSheet(
        currentQuestion: currentQ,
        onAttachToAnswer: (solutionText) {
          setState(() {
            if (_currentAnswer.trim().isEmpty) {
              _currentAnswer = solutionText;
            } else {
              _currentAnswer = "$_currentAnswer\n\n$solutionText";
            }
          });
        },
      ),
    );
  }

  void _openSystemDesignWhiteboard({bool forceModal = false}) {
    final isWide = MediaQuery.of(context).size.width >= 850;
    if (isWide && !forceModal) {
      setState(() {
        _activeSplitTool = _activeSplitTool == 'whiteboard' ? null : 'whiteboard';
      });
      return;
    }

    final currentQ = _currentQuestionIndex < widget.questions.length
        ? widget.questions[_currentQuestionIndex]
        : '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SystemDesignWhiteboardSheet(
        currentQuestion: currentQ,
        onAttachToAnswer: (architectureSummary) {
          setState(() {
            if (_currentAnswer.trim().isEmpty) {
              _currentAnswer = architectureSummary;
            } else {
              _currentAnswer = "$_currentAnswer\n\n$architectureSummary";
            }
          });
        },
      ),
    );
  }
  
  Future<void> _endInterview() async {
    _timer?.cancel();
    
    // Calculate aggregate score out of 10
    double aggregateScore = 0;
    if (_exchanges.isNotEmpty) {
      int totalRating = _exchanges.fold(0, (sum, e) => sum + e.rating);
      aggregateScore = totalRating / _exchanges.length;
    }

    // Generate conclusion message
    if (aggregateScore >= 8) {
      _conclusionText = "Excellent performance! You demonstrated strong technical knowledge and communication skills. Well done.";
    } else if (aggregateScore >= 6) {
      _conclusionText = "Good effort today. You have a solid foundation, though there are some areas where you could provide more detail. Great job overall.";
    } else if (aggregateScore >= 4) {
      _conclusionText = "Thank you for the session. You showed some good insights, but I'd recommend brushing up on some of the core concepts we discussed today.";
    } else {
      _conclusionText = "Thank you for your time. This was a challenging session, and I'd recommend more practice with these types of technical questions. Keep going!";
    }

    setState(() {
      _isConclusionPhase = true;
      _statusText = "Concluding Interview...";
      _isSpeaking = true;
      _avatarController.play();
    });

    try {
      await _speakText(_conclusionText);
    } catch (e) {
      debugPrint("Conclusion TTS Failed: $e");
    }

    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _avatarController.pause();
        _statusText = "Interview Complete";
      });
    }

    // Generate detailed summary
    final Map<String, dynamic> analysis = await _openAIService.generateOverallAnalysis(
      _exchanges.map((e) => e.toMap()).toList(),
      widget.role,
    );

    // Calculate Speech Metrics
    final speechMetrics = SpeechMetricsAnalyzer.analyze(
      answers: _exchanges.map((e) => e.answer).toList(),
      totalSpeakingSeconds: _totalCandidateSpeakingSeconds > 0
          ? _totalCandidateSpeakingSeconds
          : _exchanges.length * 40,
    );

    // Calculate Radar Scores
    RadarScores radarScores;
    if (analysis['radarScores'] != null && analysis['radarScores'] is Map) {
      radarScores = RadarScores.fromMap(Map<String, dynamic>.from(analysis['radarScores']));
    } else {
      radarScores = RadarScores.fallback(aggregateScore, speechMetrics.articulationScore);
    }

    final studyRoadmap = List<String>.from(analysis['studyRoadmap'] ?? []);

    if (!mounted) return;

    // Save full session
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user != null) {
       try {
         await FirestoreService().completeInterview(
           userId: user.uid,
           interviewId: widget.interviewId,
           exchanges: _exchanges.map((e) => e.toMap()).toList(),
           overallScore: double.parse(aggregateScore.toStringAsFixed(1)),
           strongPoints: List<String>.from(analysis['strongPoints'] ?? []),
           weakAreas: List<String>.from(analysis['weakAreas'] ?? []),
           improvementTips: List<String>.from(analysis['improvementTips'] ?? []),
           studyRoadmap: studyRoadmap,
           speechMetrics: speechMetrics.toMap(),
           radarScores: radarScores.toMap(),
         );
         debugPrint("Interview completed and saved successfully!");
       } catch (e) {
         debugPrint("Error saving interview completion: $e");
       }
    }

    if (mounted) {
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
        strongPoints: List<String>.from(analysis['strongPoints'] ?? []),
        weakAreas: List<String>.from(analysis['weakAreas'] ?? []),
        improvementTips: List<String>.from(analysis['improvementTips'] ?? []),
        studyRoadmap: studyRoadmap,
        speechMetrics: speechMetrics,
        radarScores: radarScores,
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
    try {
      if (_cameraController.value.isInitialized) {
        if (_isCameraOff) {
          await _cameraController.resumePreview();
        } else {
          await _cameraController.pausePreview();
        }
      }
    } catch (e) {
      debugPrint("Toggle camera error: $e");
    }
    setState(() => _isCameraOff = !_isCameraOff);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController.dispose();
    _avatarController.dispose();
    _elevenLabsService.dispose();
    _flutterTts.stop();
    _speech.cancel();
    super.dispose();
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Company and Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5A00).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF5A00).withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business_rounded, color: Color(0xFFFF8A00), size: 14),
                const SizedBox(width: 6),
                Text(
                  widget.companyName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(width: 6),
                const Text("•", style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(width: 6),
                Text(
                  widget.role,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Question progress badge
          if (!_isIntroductoryPhase && !_isConclusionPhase && _currentQuestionIndex < widget.questions.length)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.help_outline_rounded, color: Colors.lightBlueAccent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    "Question ${_currentQuestionIndex + 1} of ${widget.questions.length}",
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Split-Screen Toggle Pills
          InkWell(
            onTap: () => _openLiveCodeEditor(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _activeSplitTool == 'code'
                    ? Colors.lightBlueAccent.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _activeSplitTool == 'code'
                      ? Colors.lightBlueAccent
                      : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.code_rounded,
                    size: 14,
                    color: _activeSplitTool == 'code' ? Colors.lightBlueAccent : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _activeSplitTool == 'code' ? "Split Code (Active)" : "Split Code",
                    style: TextStyle(
                      color: _activeSplitTool == 'code' ? Colors.white : Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          InkWell(
            onTap: () => _openSystemDesignWhiteboard(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _activeSplitTool == 'whiteboard'
                    ? const Color(0xFFFF5A00).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _activeSplitTool == 'whiteboard'
                      ? const Color(0xFFFF8A00)
                      : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_tree_rounded,
                    size: 14,
                    color: _activeSplitTool == 'whiteboard' ? const Color(0xFFFF8A00) : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _activeSplitTool == 'whiteboard' ? "Whiteboard (Active)" : "Whiteboard",
                    style: TextStyle(
                      color: _activeSplitTool == 'whiteboard' ? Colors.white : Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Voice Mode Toggle Pill (Instant 0ms local vs Studio ElevenLabs HD)
          InkWell(
            onTap: () {
              setState(() {
                _useInstantDeviceVoice = !_useInstantDeviceVoice;
              });
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF1E1E2C),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                  content: Row(
                    children: [
                      Icon(
                        _useInstantDeviceVoice ? Icons.bolt_rounded : Icons.auto_awesome,
                        color: _useInstantDeviceVoice ? Colors.amber : const Color(0xFFFF5A00),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _useInstantDeviceVoice
                            ? "Switched to Instant Voice (0ms local latency)"
                            : "Switched to Studio Voice (ElevenLabs HD)",
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _useInstantDeviceVoice
                    ? Colors.amber.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _useInstantDeviceVoice ? Colors.amber : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _useInstantDeviceVoice ? Icons.bolt_rounded : Icons.auto_awesome,
                    size: 14,
                    color: _useInstantDeviceVoice ? Colors.amber : Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _useInstantDeviceVoice ? "Instant Voice (0ms)" : "Studio HD",
                    style: TextStyle(
                      color: _useInstantDeviceVoice ? Colors.amber : Colors.white70,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Session Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
        ],
      ),
    );
  }

  Widget _buildAIAvatarCard({required bool isWideScreen}) {
    final questionText = _transitionAnnouncement ??
        (_isIntroductoryPhase
            ? _introductoryText
            : (_isConclusionPhase
                ? _conclusionText
                : (_currentQuestionIndex < widget.questions.length
                    ? widget.questions[_currentQuestionIndex]
                    : "Interview concluding...")));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101018),
        borderRadius: BorderRadius.circular(isWideScreen ? 20 : 0),
        border: isWideScreen ? Border.all(color: Colors.white12) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Avatar Video
          if (_isAvatarInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _avatarController.value.aspectRatio,
                child: VideoPlayer(_avatarController),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology, color: Colors.white24, size: 54),
                  SizedBox(height: 12),
                  Text("AI Interviewer Initializing...", style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),

          // Status Badge (Top Left)
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5A00).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.psychology, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _statusText,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          // Question Overlay (Bottom)
          Positioned(
            bottom: 14,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, color: Color(0xFFFF8A00), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      questionText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateCard({required bool isWideScreen}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(isWideScreen ? 20 : 0),
        border: isWideScreen ? Border.all(color: Colors.white12) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              final isReady = _cameraController.value.isInitialized &&
                  !_isCameraOff &&
                  !snapshot.hasError;

              if (isReady) {
                return Center(
                  child: AspectRatio(
                    aspectRatio: _cameraController.value.aspectRatio > 0
                        ? _cameraController.value.aspectRatio
                        : (16 / 9),
                    child: CameraPreview(_cameraController),
                  ),
                );
              } else if (snapshot.hasError) {
                return Container(
                  color: const Color(0xFF14141E),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_off_rounded, color: Colors.orangeAccent, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            "Camera could not be started",
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Webcam may still be in use by Chrome. Click below to reconnect.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _initCamera();
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text("Retry Camera"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5A00),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                return Container(
                  color: const Color(0xFF14141E),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isCameraOff ? Icons.videocam_off : Icons.camera_alt_outlined,
                          color: Colors.white.withValues(alpha: 0.25),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isCameraOff ? "Camera Off" : "Starting camera preview...",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),

          // Body Language HUD (Top Left)
          Positioned(
            top: 14,
            left: 14,
            child: BodyLanguageHud(
              isCameraOff: _isCameraOff,
              isSpeaking: _isSpeaking,
              isListening: _isListening,
            ),
          ),

          // Mobile-only timer (if wide screen, header already has timer)
          if (!isWideScreen)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
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

          // Live Captions & Waveform HUD Overlay (Bottom)
          Positioned(
            bottom: 14,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isListening
                      ? const Color(0xFFFF5A00).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          LiveAudioWaveform(
                            isListening: _isListening,
                            hasDetectedSpeech: _currentAnswer.isNotEmpty,
                          ),
                          if (!_isListening)
                            const Row(
                              children: [
                                Icon(Icons.subtitles_rounded, color: Colors.white54, size: 14),
                                SizedBox(width: 6),
                                Text("Live Transcript", style: TextStyle(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                        ],
                      ),
                      if (_isListening)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: _openLiveCodeEditor,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.code_rounded, color: Colors.lightBlueAccent, size: 14),
                                    SizedBox(width: 4),
                                    Text("Code", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _openSystemDesignWhiteboard,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.account_tree_rounded, color: Color(0xFFFF8A00), size: 14),
                                    SizedBox(width: 4),
                                    Text("Board", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _showTextAnswerDialog,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_note_rounded, color: Colors.white70, size: 14),
                                    SizedBox(width: 4),
                                    Text("Type", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentAnswer.isNotEmpty
                        ? _currentAnswer
                        : (_isListening
                            ? "Listening to your answer... Speak naturally, or tap 'Type', 'Code', or 'Board' above."
                            : "Waiting for question to conclude..."),
                    style: TextStyle(
                      color: _currentAnswer.isNotEmpty ? Colors.white : Colors.white54,
                      fontStyle: _currentAnswer.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                      fontSize: 13,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_isListening) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, color: Color(0xFFFF8A00), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          "Finished? Tap 'Done Speaking' for instant evaluation (or wait 3s)",
                          style: TextStyle(
                            color: const Color(0xFFFF8A00).withValues(alpha: 0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterControls({required bool isWideScreen}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D14),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
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
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text("Don't Know", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _showTextAnswerDialog,
                              icon: const Icon(Icons.keyboard_alt_rounded, size: 16),
                              label: const Text("Type Answer", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.12),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _openLiveCodeEditor,
                              icon: const Icon(Icons.code_rounded, size: 16, color: Colors.lightBlueAccent),
                              label: const Text("Code Editor", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.12),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _openSystemDesignWhiteboard,
                              icon: const Icon(Icons.account_tree_rounded, size: 16, color: Color(0xFFFF8A00)),
                              label: const Text("Whiteboard", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.12),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _stopListeningAndProcess,
                              icon: const Icon(Icons.check_circle_rounded, size: 16),
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
                            child: Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _openLiveCodeEditor,
                                  icon: const Icon(Icons.code_rounded, size: 16, color: Colors.lightBlueAccent),
                                  label: const Text("Code Editor", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: _openSystemDesignWhiteboard,
                                  icon: const Icon(Icons.account_tree_rounded, size: 16, color: Color(0xFFFF8A00)),
                                  label: const Text("Whiteboard", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
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
                      case 'code': _openLiveCodeEditor(); break;
                      case 'whiteboard': _openSystemDesignWhiteboard(); break;
                      case 'camera': _toggleCamera(); break;
                      case 'mic': _startListening(); break;
                      case 'voice_toggle':
                        setState(() {
                          _useInstantDeviceVoice = !_useInstantDeviceVoice;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF1E1E2C),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            duration: const Duration(seconds: 2),
                            content: Text(
                              _useInstantDeviceVoice
                                  ? "Switched to Instant Voice (0ms latency)"
                                  : "Switched to ElevenLabs HD (Studio voice)",
                            ),
                          ),
                        );
                        break;
                      case 'end': Navigator.pop(context); break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'voice_toggle',
                      child: Row(
                        children: [
                          Icon(
                            _useInstantDeviceVoice ? Icons.bolt_rounded : Icons.auto_awesome,
                            color: _useInstantDeviceVoice ? Colors.amber : const Color(0xFFFF5A00),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _useInstantDeviceVoice ? "Use Studio Voice (ElevenLabs)" : "Use Instant Voice (0ms local)",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    const PopupMenuItem(
                      value: 'code',
                      child: Row(
                        children: [
                          Icon(Icons.code_rounded, color: Colors.lightBlueAccent, size: 20),
                          SizedBox(width: 12),
                          Text("Live Code Editor", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'whiteboard',
                      child: Row(
                        children: [
                          Icon(Icons.account_tree_rounded, color: Color(0xFFFF8A00), size: 20),
                          SizedBox(width: 12),
                          Text("System Design Whiteboard", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
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
                    const PopupMenuItem(
                      value: 'mic',
                      child: Row(
                        children: [
                          Icon(Icons.mic, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text("Reset Microphone", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(height: 1),
                    const PopupMenuItem(
                      value: 'end',
                      child: Row(
                        children: [
                          Icon(Icons.call_end, color: Colors.redAccent, size: 20),
                          SizedBox(width: 12),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth >= 850;

            return Column(
              children: [
                // Top Header for Laptop / Desktop
                if (isWideScreen) _buildTopHeader(),

                // Main Video Area
                Expanded(
                  child: isWideScreen
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: _activeSplitTool != null
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Left Video Column (AI Interviewer + Candidate Studio)
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: _buildAIAvatarCard(isWideScreen: true),
                                          ),
                                          const SizedBox(height: 12),
                                          Expanded(
                                            flex: 1,
                                            child: _buildCandidateCard(isWideScreen: true),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Right Tool Panel (Embedded Live Code Editor or Whiteboard)
                                    Expanded(
                                      flex: 6,
                                      child: _activeSplitTool == 'code'
                                          ? LiveCodeEditorSheet(
                                              isEmbedded: true,
                                              currentQuestion: _currentQuestionIndex < widget.questions.length
                                                  ? widget.questions[_currentQuestionIndex]
                                                  : '',
                                              onClose: () => setState(() => _activeSplitTool = null),
                                              onAttachToAnswer: (solutionText) {
                                                setState(() {
                                                  if (_currentAnswer.trim().isEmpty) {
                                                    _currentAnswer = solutionText;
                                                  } else {
                                                    _currentAnswer = "$_currentAnswer\n\n$solutionText";
                                                  }
                                                });
                                              },
                                            )
                                          : SystemDesignWhiteboardSheet(
                                              isEmbedded: true,
                                              currentQuestion: _currentQuestionIndex < widget.questions.length
                                                  ? widget.questions[_currentQuestionIndex]
                                                  : '',
                                              onClose: () => setState(() => _activeSplitTool = null),
                                              onAttachToAnswer: (architectureSummary) {
                                                setState(() {
                                                  if (_currentAnswer.trim().isEmpty) {
                                                    _currentAnswer = architectureSummary;
                                                  } else {
                                                    _currentAnswer = "$_currentAnswer\n\n$architectureSummary";
                                                  }
                                                });
                                              },
                                            ),
                                    ),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Left: AI Interviewer Card
                                    Expanded(
                                      flex: 1,
                                      child: _buildAIAvatarCard(isWideScreen: true),
                                    ),
                                    const SizedBox(width: 16),
                                    // Right: Candidate Studio Card
                                    Expanded(
                                      flex: 1,
                                      child: _buildCandidateCard(isWideScreen: true),
                                    ),
                                  ],
                                ),
                        )
                      : Column(
                          children: [
                            Expanded(child: _buildAIAvatarCard(isWideScreen: false)),
                            Container(height: 1, color: Colors.white24),
                            Expanded(child: _buildCandidateCard(isWideScreen: false)),
                          ],
                        ),
                ),

                // Footer Controls
                _buildFooterControls(isWideScreen: isWideScreen),
              ],
            );
          },
        ),
      ),
    );
  }
}
