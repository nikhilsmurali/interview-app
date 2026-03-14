import 'dart:convert';
import 'package:ai_interviewer/core/secrets/app_secrets.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String _apiKey = AppSecrets.groqApiKey;
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  Future<List<String>> generateInterviewQuestions(String company, String role) async {
    final prompt = '''You are a strict, senior technical interviewer at $company interviewing a candidate for the $role position.

Generate exactly 5 highly specific, challenging interview questions tailored to the $role role.

Rules:
- Each question must be a single concise sentence.
- Questions must heavily test domain-specific knowledge, practical scenarios, or advanced concepts relevant to $role at $company.
- Do NOT include generic HR or behavioral questions like "Tell me about yourself" or "What are your weaknesses?"
- Focus specifically on the tools, technologies, methodologies, and typical challenges faced by a $role.
- Ensure practical depth but keep questions brief (max 20-25 words per question).

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
          'model': 'llama3-8b-8192',
          'messages': [
            {'role': 'system', 'content': 'You are a helpful technical interviewer.'},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode != 200) {
        print('OpenAI Error: ${response.statusCode} - ${response.body}');
        return _getFallbackQuestions(company, role);
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final String text = data['choices'][0]['message']['content'];

      // Parse numbering gracefully (handle markdown like "**1. Question**" or "1. Question")
      final questions = text
          .split('\n')
          .where((line) => line.trim().isNotEmpty && RegExp(r'\d+\.').hasMatch(line))
          .map((line) {
            // Remove the leading number, period, spaces, and any markdown asterisks
            return line.replaceFirst(RegExp(r'^.*?^?\d+\.\s*\*?\*?\s*'), '').replaceAll('**', '').trim();
          })
          .toList();

      return questions.isEmpty ? _getFallbackQuestions(company, role) : questions.take(5).toList();
    } catch (e) {
      print('OpenAI API Exception: $e');
      return _getFallbackQuestions(company, role);
    }
  }

  Future<Map<String, dynamic>> evaluateAnswer(String question, String answer, String role) async {
    final prompt = '''
Role: $role
Question: $question
Candidate Answer: $answer

Task: Evaluate the candidate's answer.

CRITICAL INSTRUCTIONS:
1. If the candidate's answer is "No answer provided.", "I don't know", extremely short, unclear, or completely unrelated to the question, DO NOT say "Good answer". Instead, set the feedback to something like "I didn't quite catch that, could you please clarify or try again?", or point out that they didn't answer the question. Set the rating to 0.
2. If the candidate gives a genuine technical answer, evaluate its accuracy and depth constructively.
3. Be conversational but professional.

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
          'model': 'llama3-8b-8192',
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
      return {"feedback": "I couldn't evaluate that properly. Let's move on.", "rating": 5, "followUp": null};
    } catch (e) {
      return {"feedback": "There was an error processing your answer. Please try again.", "rating": 0, "followUp": null};
    }
  }

  List<String> _getFallbackQuestions(String company, String role) {
    final lowerRole = role.toLowerCase();
    
    if (lowerRole.contains('flutter') || lowerRole.contains('dart')) {
      return [
        'Welcome to $company. As a $role, how would you optimize a ListView with thousands of items to prevent frame drops?',
        'When building large scale applications here at $company, when would you choose BLoC over Provider for state?',
        'Describe how to handle background tasks when the app is minimized or terminated.',
        'What is your approach to securing sensitive keys using Flutter Secure Storage?',
        'How do you debug an issue that only occurs on native iOS/Android code via Platform Channels?'
      ];
    } else if (lowerRole.contains('frontend') || lowerRole.contains('react') || lowerRole.contains('angular') || lowerRole.contains('vue')) {
      return [
        'Welcome to $company. As a $role, how do you handle state management across deeply nested components?',
        'What strategies do you use to optimize the rendering performance of a web application?',
        'Explain how you would implement client-side caching and offline support for our web app.',
        'How do you ensure web accessibility (a11y) standards are met in your components?',
        'Describe your approach to handling cross-browser compatibility issues.'
      ];
    } else if (lowerRole.contains('backend') || lowerRole.contains('node') || lowerRole.contains('python') || lowerRole.contains('java') || lowerRole.contains('go')) {
       return [
        'Welcome to $company. As a $role, how do you design scalable APIs capable of handling high traffic?',
        'Explain how you enforce data integrity and manage complex database migrations.',
        'What caching strategies would you implement to reduce database load?',
        'How do you manage authentication and securely store user credentials?',
        'Describe a situation where you had to troubleshoot and fix a memory leak or performance bottleneck on the server.'
      ];
    } else if (lowerRole.contains('data') || lowerRole.contains('machine learning') || lowerRole.contains('ai')) {
       return [
        'Welcome to $company. As a $role, how do you deal with missing or anomalous data in your datasets?',
        'Explain the trade-offs between picking a complex deep learning model versus a simpler regression model.',
        'How do you deploy and monitor a machine learning model in production?',
        'What metrics do you use to evaluate the performance of classification models?',
        'Describe a time you optimized an ETL pipeline for better performance.'
      ];
    }
    
    return [
      'Welcome to $company. As a $role, can you describe how you architect solutions for complex engineering problems?',
      'What are the most critical technical skills needed to succeed as a $role at $company?',
      'How do you ensure code quality, testing, and security in your day-to-day work?',
      'Can you explain a difficult technical concept related to being a $role to a non-engineer?',
      'What modern industry methodologies would you bring to improve our engineering workflows at $company?'
    ];
  }
}
