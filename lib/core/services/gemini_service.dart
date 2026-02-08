import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // TODO: Move API key to .env or secure storage in production
  static const String _apiKey = 'AIzaSyBIaG6_mpsedHUIP3HMh2xRnbSRN63PvW0';
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
    );
  }

  Future<List<String>> generateInterviewQuestions(String company, String role) async {
    final prompt = '''You are a senior technical interviewer at $company.

Generate exactly 5 strictly technical interview questions for a $role position.

Rules:
- Questions must test hands-on technical knowledge and problem-solving
- Do NOT include HR, behavioral, motivational, or career questions
- Do NOT ask about company culture, strengths/weaknesses, or future plans
- Each question must be specific to the $role and its core technologies
- Prefer "how", "why", or scenario-based technical questions

Return only a numbered list of questions. No explanations.''';
    
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text == null) return [];

      // Parse the response to get individual questions
      final questions = response.text!
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim())
          .toList();

      return questions;
    } catch (e) {
      // Fallback questions if API fails
      return [
        'Tell me about your experience with $role.',
        'Why do you want to work at $company?',
        'Describe a challenging project you worked on.',
        'What are your strengths and weaknesses?',
        'Where do you see yourself in 5 years?'
      ];
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
      
      return {
        "feedback": jsonString, 
      };
    } catch (e) {
      return {
        "feedback": "Could not evaluate answer.",
      };
    }
  }
}
