import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AiAvatar extends StatefulWidget {
  const AiAvatar({super.key});

  @override
  State<AiAvatar> createState() => _AiAvatarState();
}

class _AiAvatarState extends State<AiAvatar> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/avatar_video.mp4')
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.setLooping(true);
        _controller.setVolume(0.0); // Mute the video
        _controller.play();
      }).catchError((error) {
        debugPrint("Error initializing video player: $error");
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow/Border
          Container(
             width: 190,
             height: 190,
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               border: Border.all(
                 color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                 width: 2,
               ),
               boxShadow: [
                 BoxShadow(
                   color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                   blurRadius: 20,
                   spreadRadius: 2,
                 ),
               ],
             ),
          ),

          // Video Circle
          Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black, // Background while loading
            ),
            clipBehavior: Clip.hardEdge,
            child: _initialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6366F1),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
