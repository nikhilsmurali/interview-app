import 'dart:convert';
import 'package:ai_interviewer/core/secrets/app_secrets.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String _apiKey = AppSecrets.openAiApiKey;
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  Future<List<String>> generateInterviewQuestions(String company, String role) async {
    final prompt = '''You are a senior technical interviewer at $company hiring for the $role position.

Generate exactly 5 strictly technical interview questions. 

Rules:
- Each question must be a single concise sentence.
- Questions must test hands-on engineering knowledge (scenario-based or implementation-focused).
- Do NOT include HR, behavioral, or generic textbook questions.
- Reference real tools or architectures relevant to $role at $company.
- Focus on practical depth but keep it brief (max 20-25 words per question).

Role-specific areas:
- Frontend: Rendering, DOM, CSS performance, State, APIs.
- Backend: DB transactions, Caching, API design, Concurrency.
- Flutter: Widget lifecycle, State management, Native integration, Performance.
- DevOps: CI/CD, K8s, Terraform, Monitoring, Scaling.

Output format:
- Return ONLY a numbered list of 5 questions.
- No explanations, no markdown blocks, no extra text.
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'system', 'content': 'You are a helpful technical interviewer.'},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode != 200) {
        print('OpenAI Error: ${response.statusCode} - ${response.body}');
        return _getFallbackQuestions(role);
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final String text = data['choices'][0]['message']['content'];

      // Parse numbering
      final questions = text
          .split('\n')
          .where((line) => line.trim().isNotEmpty && RegExp(r'^\d+\.').hasMatch(line))
          .map((line) => line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim())
          .toList();

      return questions.isEmpty ? _getFallbackQuestions(role) : questions.take(5).toList();
    } catch (e) {
      print('OpenAI API Exception: $e');
      return _getFallbackQuestions(role);
    }
  }

  Future<Map<String, dynamic>> evaluateAnswer(String question, String answer, String role) async {
    final prompt = '''
Role: $role
Question: $question
Candidate Answer: $answer

Task: Evaluate the candidate's answer.
Output JSON only:
{
  "feedback": "Short constructive feedback (max 2 sentences).",
  "rating": 1-10,
  "followUp": "A follow-up question if needed, else null"
}
''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {'role': 'system', 'content': 'You evaluate technical interview answers. Output valid JSON only.'},
            {'role': 'user', 'content': prompt}
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String content = data['choices'][0]['message']['content'];
        return jsonDecode(content);
      }
      return {"feedback": "Good answer.", "rating": 5, "followUp": null};
    } catch (e) {
      return {"feedback": "Error evaluating answer.", "rating": 0, "followUp": null};
    }
  }

  List<String> _getFallbackQuestions(String role) {
    if (role.toLowerCase().contains('flutter')) {
      return [
        'How do you optimize a ListView with thousands of items to prevent frame drops?',
        'When would you choose BLoC over Provider for global state management?',
        'Describe how to handle background tasks when the app is minimized or terminated.',
        'What is your approach to securing sensitive keys using Flutter Secure Storage?',
        'How do you debug an issue that only occurs on native iOS/Android code via Platform Channels?'
      ];
    }
    return [
      'Explain the request-response cycle in detail.',
      'How do you handle state management in complex applications?',
      'Describe a difficult bug you fixed and your debugging process.',
      'Compare SQL vs NoSQL databases in terms of scalability.',
      'How do you optimize application performance?'
    ];
  }
}
