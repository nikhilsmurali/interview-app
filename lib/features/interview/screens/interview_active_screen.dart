import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class InterviewActiveScreen extends StatefulWidget {
  final String companyName;
  final String role;
  final CameraDescription camera;

  const InterviewActiveScreen({
    super.key,
    required this.companyName,
    required this.role,
    required this.camera,
  });

  @override
  State<InterviewActiveScreen> createState() => _InterviewActiveScreenState();
}

class _InterviewActiveScreenState extends State<InterviewActiveScreen> {
  // Camera
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  bool _isCameraOff = false;
  bool _isMicMuted = false;

  // Avatar Video
  late VideoPlayerController _avatarController;
  bool _isAvatarInitialized = false;

  // Timer
  Timer? _timer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initAvatar();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  void _initCamera() {
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: true,
    );
    _initializeControllerFuture = _cameraController.initialize();
  }

  void _initAvatar() {
    _avatarController = VideoPlayerController.asset('assets/videos/avatar_video.mp4')
      ..initialize().then((_) {
        setState(() => _isAvatarInitialized = true);
        _avatarController.setLooping(true);
        // User requested "keep it as a paused state"
        _avatarController.pause(); 
      });
  }

  Future<void> _toggleMic() async {
    if (_isMicMuted) {
      // Unmuting not directly supported by CameraController without re-init often, 
      // but strictly speaking we just want the state visual here or stopping stream if possible.
      // For now, we'll just toggle the UI state as real mute usually involves stopping audio stream processing.
      // Since specific candidate audio streaming isn't fully implemented (just preview), UI toggle is sufficient.
    }
    setState(() => _isMicMuted = !_isMicMuted);
  }

  Future<void> _toggleCamera() async {
    if (_isCameraOff) {
      await _cameraController.resumePreview();
    } else {
      await _cameraController.pausePreview();
    }
    setState(() => _isCameraOff = !_isCameraOff);
  }

  Future<void> _onExitPressed() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('End Interview?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to end this interview session?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Interview', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      Navigator.of(context).pop(); // Return to home/prep
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // TOP HALF: Avatar (Paused)
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.black,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isAvatarInitialized)
                      AspectRatio(
                        aspectRatio: _avatarController.value.aspectRatio,
                        child: VideoPlayer(_avatarController),
                      )
                    else
                      const Center(child: CircularProgressIndicator()),
                      
                    // Paused Text
                    const Positioned(
                      bottom: 16,
                      child: Text("AI Interviewer (Paused)", style: TextStyle(color: Colors.white54)),
                    ),

                    // TIMER OVERLAY (Top Right)
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
            ),
// ... rest of the build method (bottom half, footer, etc.)

            // SEPARATOR
            const Divider(height: 1, color: Colors.white24),

            // BOTTOM HALF: Candidate Camera
            Expanded(
              flex: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        if (_isCameraOff) {
                          return const Center(
                            child: Icon(Icons.videocam_off, color: Colors.white24, size: 64),
                          );
                        }
                        return CameraPreview(_cameraController);
                      } else {
                        return const Center(child: CircularProgressIndicator());
                      }
                    },
                  ),
                  
                  // Muted Indicator Overlay
                  if (_isMicMuted)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mic_off, color: Colors.white, size: 20),
                      ),
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
                  // Mic Toggle
                  _buildControlBtn(
                    icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                    color: _isMicMuted ? Colors.redAccent : Colors.white,
                    onTap: _toggleMic,
                    label: _isMicMuted ? 'Unmute' : 'Mute',
                  ),

                  // Camera Toggle
                  _buildControlBtn(
                    icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    color: _isCameraOff ? Colors.redAccent : Colors.white,
                    onTap: _toggleCamera,
                    label: _isCameraOff ? 'Start Video' : 'Stop Video',
                  ),

                  // Exit
                  _buildControlBtn(
                    icon: Icons.call_end,
                    color: Colors.red,
                    bgColor: Colors.red.withValues(alpha: 0.2),
                    onTap: _onExitPressed,
                    label: 'End',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
    Color? bgColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor ?? Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
