import 'dart:convert';
import 'dart:io';

import 'package:ai_interviewer/core/secrets/eleven_labs_secrets.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class ElevenLabsService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> speak(String text) async {
    try {
      final url = Uri.parse(
          'https://api.elevenlabs.io/v1/text-to-speech/${ElevenLabsSecrets.voiceId}');

      final response = await http.post(
        url,
        headers: {
          'xi-api-key': ElevenLabsSecrets.apiKey,
          'Content-Type': 'application/json',
          'accept': 'audio/mpeg',
        },
        body: jsonEncode({
          "text": text,
          "model_id": "eleven_flash_v2_5", 
          "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.75,
          }
        }),
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/speech_temp.mp3');
        if (await file.exists()) {
             await file.delete(); 
        }
        await file.writeAsBytes(bytes);

        try {
            await _audioPlayer.setFilePath(file.path);
            await _audioPlayer.play();
            await _audioPlayer.processingStateStream.firstWhere((state) => state == ProcessingState.completed);
        } catch (audioError) {
            print("ElevenLabsService AudioPlayer Error: $audioError");
        }
      } else {
        throw Exception('ElevenLabs API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print("Error generating speech: $e");
      rethrow; 
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
