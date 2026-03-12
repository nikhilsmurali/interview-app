import 'dart:convert';
import 'package:ai_interviewer/core/secrets/app_secrets.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String _apiKey = AppSecrets.geminiApiKey;
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash', // Standard stable version
      apiKey: _apiKey,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );
  }

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
- Each question must be on a single line.
- No explanations or extra text.
''';
    
    try {
      print('--- Generating questions for $company | $role ---');
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null || response.text!.isEmpty) {
        print('Gemini returned an empty response.');
        return _getFallbackQuestions(role);
      }

      // Parse the response to get individual questions
      final questions = response.text!
          .split('\n')
          .where((line) => line.trim().isNotEmpty && RegExp(r'^\d+\.').hasMatch(line))
          .map((line) => line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim())
          .toList();

      if (questions.isEmpty) {
        print('Gemini response format invalid: ${response.text}');
        return _getFallbackQuestions(role);
      }

      print("Gemini Generated ${questions.length} Questions successfully.");
      return questions.take(5).toList();
    } catch (e) {
      print('!!! Gemini API ERROR: $e');
      return _getFallbackQuestions(role);
    }
  }

  // Improved role-specific fallback questions
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

  Future<String> generateNextQuestion(String company, String role, String history, String lastAnswer) async {
    final prompt = '''You are a strict technical interviewer from $company hiring for $role.

This is a REAL interactive interview.

Interview history so far:
$history

Candidate's last answer:
$lastAnswer

Instructions:
- Ask ONLY ONE next question
- The question MUST depend on the candidate's last answer
- If they mentioned a project → ask deeper technical question
- If they mentioned a technology → ask how they used it
- If answer is vague → ask clarification
- If answer is strong → move to next topic relevant to $company

IMPORTANT:
Do NOT generate multiple questions.
Do NOT generate a list.
Generate only the next interviewer question text.''';
    
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? "Can you elaborate on that?";
    } catch (e) {
      return "Can you give me an example?";
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
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null) return {};

      // Basic cleaning to ensure JSON
      String jsonString = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
      
      try {
        final Map<String, dynamic> parsedJson = jsonDecode(jsonString);
        return parsedJson;
      } catch (e) {
        return {
          "feedback": response.text ?? "Thank you for your answer.", 
          "rating": 0,
          "followUp": null
        };
      }
    } catch (e) {
      print('Gemini Evaluation Error: $e');
      // Fallback to avoid "Could not evaluate" message
      return {
        "feedback": "That's a reasonable answer. Continue to the next question.",
        "rating": 7,
        "followUp": null
      };
    }
  }
}
