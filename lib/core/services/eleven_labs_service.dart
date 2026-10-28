import 'dart:async';
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

  /// Speaks [text] through ElevenLabs.
  ///
  /// [isSuperseded] is polled at each async step so that an utterance which has
  /// been replaced by a newer one aborts instead of talking over it.
  Future<void> speak(String text, {bool Function()? isSuperseded}) async {
    final cleanText = sanitizeText(text);
    if (cleanText.isEmpty) return;

    bool cancelled() => isSuperseded?.call() ?? false;

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

      if (cancelled()) return;

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final audioSource = AudioSource.uri(
          Uri.dataFromBytes(bytes, mimeType: 'audio/mpeg'),
        );

        await _audioPlayer.stop();
        await _audioPlayer.setVolume(1.0); // Enforce constant 100% volume
        await _audioPlayer.setAudioSource(audioSource);

        if (cancelled()) {
          await _audioPlayer.stop();
          return;
        }

        await _audioPlayer.play();

        // Wait for actual completion. The previous predicate also matched the
        // transient "ready but not playing" state, which returned immediately
        // while the MP3 was still audible.
        final maxWait =
            (_audioPlayer.duration ?? const Duration(minutes: 3)) +
                const Duration(seconds: 5);
        try {
          await _audioPlayer.playerStateStream
              .firstWhere((state) =>
                  state.processingState == ProcessingState.completed)
              .timeout(maxWait);
        } on TimeoutException {
          debugPrint("ElevenLabs playback timed out; stopping audio");
          await _audioPlayer.stop();
        }
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
