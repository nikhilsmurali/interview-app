import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ai_interviewer/core/secrets/eleven_labs_secrets.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

class ElevenLabsService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  ElevenLabsService() {
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    try {
      _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint("Error initializing audio player volume: $e");
    }
  }

  static String sanitizeText(String text) {
    return text
        .replaceAll(RegExp(r'[*_#`~]'), '')
        .replaceAll(RegExp(r'^\s*\d+[\.\)]\s*'), '')
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> speak(String text) async {
    final cleanText = sanitizeText(text);
    if (cleanText.isEmpty) return;

    try {
      final url = Uri.parse(
          'https://api.elevenlabs.io/v1/text-to-speech/${ElevenLabsSecrets.voiceId}?optimize_streaming_latency=3');

      final response = await http.post(
        url,
        headers: {
          'xi-api-key': ElevenLabsSecrets.apiKey,
          'Content-Type': 'application/json',
          'accept': 'audio/mpeg',
        },
        body: jsonEncode({
          "text": cleanText,
          "model_id": "eleven_flash_v2_5",
          "voice_settings": {
            // High stability (0.85) ensures a steady, constant, and uniform volume.
            // Low stability causes the AI to fluctuate between whispering (mild) and loud spikes.
            "stability": 0.85,
            "similarity_boost": 0.85,
            "style": 0.0,
            "use_speaker_boost": true,
          }
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final audioSource = AudioSource.uri(
          Uri.dataFromBytes(bytes, mimeType: 'audio/mpeg'),
        );

        await _audioPlayer.stop();
        await _audioPlayer.setVolume(1.0); // Enforce constant 100% volume
        await _audioPlayer.setAudioSource(audioSource);
        await _audioPlayer.play();
        // Wait until playback completes with timeout safety
        await _audioPlayer.playerStateStream.firstWhere(
          (state) =>
              state.processingState == ProcessingState.completed ||
              (!state.playing && state.processingState == ProcessingState.ready && _audioPlayer.position >= (_audioPlayer.duration ?? Duration.zero)),
        ).timeout(const Duration(seconds: 15), onTimeout: () {
          debugPrint("ElevenLabs playback wait completed/timed out");
          return _audioPlayer.playerState;
        });
      } else {
        throw Exception('ElevenLabs API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint("ElevenLabsService Error: $e");
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint("Error stopping ElevenLabs audio: $e");
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
