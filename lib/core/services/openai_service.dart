import 'dart:convert';
import 'package:ai_interviewer/core/secrets/app_secrets.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String _groqApiKey = AppSecrets.groqApiKey;
  static const String _groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  static const String _geminiApiKey = AppSecrets.geminiApiKey;
  static const String _geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey';

  Future<List<String>> generateInterviewQuestions(String company, String role, [String? resume, String difficulty = 'Medium']) async {
    int numQuestions = 5;
    if (difficulty == 'Medium') numQuestions = 7;
    if (difficulty == 'Hard') numQuestions = 10;
    
    String difficultyPrompt = '';
    if (difficulty == 'Easy') {
      difficultyPrompt = 'Keep questions strictly at a foundational level. Focus on basic definitions, core syntax, and simple "what is" or "how to" questions. Avoid architectural discussions or complex logic scenarios.';
    } else if (difficulty == 'Medium') {
      difficultyPrompt = 'Focus on solid mid-level experience and practical scenarios.';
    } else {
      difficultyPrompt = 'Make the questions extremely advanced, testing expert-level architecture and deep systems knowledge.';
    }

    String basePrompt = '''You are a strict, senior technical interviewer at $company interviewing a candidate for the $role position.

Generate exactly $numQuestions highly specific interview questions tailored to the $role role.
Difficulty Level: $difficulty - $difficultyPrompt

Rules:
- Each question must be a single concise sentence.
- Questions must heavily test domain-specific knowledge, practical scenarios, or advanced concepts relevant to $role at $company.
- Do NOT include generic HR or behavioral questions like "Tell me about yourself" or "What are your weaknesses?"
- Focus specifically on the tools, technologies, methodologies, and typical challenges faced by a $role.
- Output ONLY a numbered list of $numQuestions questions. No extra text.
''';

    if (resume != null && resume.trim().isNotEmpty) {
      basePrompt += '\nCandidate Resume:\n$resume';
    }

    // --- STEP 1: Try Groq ---
    try {
      print('>>> [API] Calling Groq (Llama 3.3-70B)...');
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [{'role': 'user', 'content': basePrompt}],
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final content = jsonDecode(response.body)['choices'][0]['message']['content'];
        print('>>> [RAW AI RESPONSE]:\n$content'); // IMPORTANT for viva/debugging
        
        final List<String> questions = _parseQuestions(content, numQuestions);
        if (questions.isNotEmpty) {
           print('>>> [SUCCESS] Successfully extracted ${questions.length} questions.');
           return questions;
        }
        print('!!! [PARSING FAILED] AI returned text but no questions were found. Trying backup...');
      } else {
        print('!!! [GROQ ERROR] Status: ${response.statusCode} | Body: ${response.body}');
      }
    } catch (e) {
      print('!!! [GROQ EXCEPTION]: $e');
    }

    // --- STEP 2: Try Gemini (Failover) ---
    try {
      if (_geminiApiKey.isEmpty || _geminiApiKey.contains('YOUR_GEMINI')) {
        print('!!! [BACKUP] Gemini key missing. Using fallbacks.');
        return _getFallbackQuestions(company, role, numQuestions);
      }

      print('>>> [API] Calling Gemini Backup...');
      final response = await http.post(
        Uri.parse(_geminiBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{
            'parts': [{'text': basePrompt}]
          }],
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String text = data['candidates'][0]['content']['parts'][0]['text'];
        print('>>> [GEMINI RESPONSE]:\n$text');
        
        final List<String> questions = _parseQuestions(text, numQuestions);
        if (questions.isNotEmpty) return questions;
      }
    } catch (e) {
      print('!!! [GEMINI EXCEPTION]: $e');
    }

    return _getFallbackQuestions(company, role, numQuestions);
  }

  /// REBUILT: Extremely resilient parser for the viva
  List<String> _parseQuestions(String text, int limit) {
    if (text.isEmpty) return [];
    
    // Split by lines and clean them up
    List<String> lines = text.split('\n').map((s) => s.trim()).toList();
    List<String> questions = [];

    for (var line in lines) {
      if (line.isEmpty) continue;

      // Detect lines that start with numbers, bullets, or are clearly questions
      bool isMatch = RegExp(r'^(\d+[\.\)]|[-\*•])').hasMatch(line) || line.endsWith('?');
      
      if (isMatch) {
         // Clean prefixes like "1. ", "- ", "**2. ", "Question: ", etc.
         String clean = line
             .replaceFirst(RegExp(r'^.*?(\d+[\.\)]|[-\*•])\s*'), '') // Remove number/bullet
             .replaceAll('**', '') // Remove bolding
             .replaceAll(RegExp(r'^Question\s*\d*:\s*'), '') // Remove "Question 1:" words
             .trim();
             
         if (clean.length > 10) {
            questions.add(clean);
         }
      }
      if (questions.length >= limit) break; 
    }

    // fallback: if no list found, find any line that ends in '?'
    if (questions.isEmpty) {
      questions = lines
          .where((l) => l.endsWith('?') && l.length > 15)
          .take(limit)
          .toList();
    }

    return questions;
  }

  Future<Map<String, dynamic>> evaluateAnswer(String question, String answer, String role, [String difficulty = 'Medium']) async {
    final prompt = '''Evaluate:
Role: $role
Difficulty Level: $difficulty
Question: $question
Answer: $answer
Rules for $difficulty mode:
${difficulty == 'Easy' ? '- Be encouraging and positive.\n- Only provide a follow-up question if the answer is completely missing core concepts, but keep it extremely simple.' : '- Provide constructive technical feedback.\n- Feel free to ask a challenging follow-up if the answer shows depth.'}

Output JSON: {"feedback": "2 sentences", "rating": 1-10, "followUp": "question or null"}''';

    try {
      // Try Groq for evaluation
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [{'role': 'user', 'content': prompt}],
          'response_format': {'type': 'json_object'},
          'temperature': 0,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(jsonDecode(response.body)['choices'][0]['message']['content']);
      }
    } catch (e) {
      print('Evaluation error: $e');
    }

    return {"feedback": "Good answer. Let's continue.", "rating": 7, "followUp": null};
  }
  
  Future<Map<String, dynamic>> generateOverallAnalysis(List<Map<String, dynamic>> exchanges, String role) async {
    final transcript = exchanges.map((e) => "Q: ${e['question']}\nA: ${e['answer']}\nFeedback: ${e['feedback']}").join("\n\n");
    
    final prompt = '''As a senior technical interviewer, provide a final comprehensive summary for a $role candidate based on this transcript:
    
$transcript

Analyze both technical proficiency and non-technical aspects (communication, clarity, speech correctness).

Output exactly in this JSON format:
{
  "strongPoints": ["point 1", "point 2"],
  "weakAreas": ["area 1", "area 2"],
  "improvementTips": ["Technical: tip 1", "Non-Technical: tip 2"]
}''';

    try {
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [{'role': 'user', 'content': prompt}],
          'response_format': {'type': 'json_object'},
          'temperature': 0,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(jsonDecode(response.body)['choices'][0]['message']['content']);
      }
    } catch (e) {
      print('Summary generation error: $e');
    }

    return {
      "strongPoints": ["Communicative", "Attempted all questions"],
      "weakAreas": ["Deeper technical knowledge", "Specific concept clarity"],
      "improvementTips": ["Technical: Study more core concepts", "Non-Technical: Speak more clearly and structure your answers"]
    };
  }

  List<String> _getFallbackQuestions(String company, String role, int limit) {
    final lowerRole = role.toLowerCase();
    
    List<String> baseQuestions = [];
    if (lowerRole.contains('flutter') || lowerRole.contains('dart')) {
      baseQuestions = [
        'Welcome to $company. As a $role, how would you optimize a ListView with thousands of items to prevent frame drops?',
        'When building large scale applications here at $company, when would you choose BLoC over Provider for state?',
        'Describe how to handle background tasks when the app is minimized or terminated.',
        'What is your approach to securing sensitive keys using Flutter Secure Storage?',
        'How do you debug an issue that only occurs on native iOS/Android code via Platform Channels?',
        'How does Flutter rendering work under the hood?',
        'What are the advantages of using Isolates in Dart for multi-threading?',
        'Explain the differences between Hot Reload and Hot Restart.',
        'How do you create custom animations using AnimationController?',
        'Describe how the widget tree, element tree, and render tree communicate.'
      ];
    } else if (lowerRole.contains('frontend') || lowerRole.contains('react') || lowerRole.contains('angular') || lowerRole.contains('vue')) {
      baseQuestions = [
        'Welcome to $company. As a $role, how do you handle state management across deeply nested components?',
        'What strategies do you use to optimize the rendering performance of a web application?',
        'Explain how you would implement client-side caching and offline support for our web app.',
        'How do you ensure web accessibility (a11y) standards are met in your components?',
        'Describe your approach to handling cross-browser compatibility issues.',
        'What are the differences between client-side rendering and server-side rendering?',
        'How does the Virtual DOM work and why is it faster?',
        'Explain the concepts of debouncing and throttling.',
        'How do you tackle memory leaks in single-page applications?',
        'What strategies exist for managing complex CSS architectures in large web apps?'
      ];
    } else if (lowerRole.contains('backend') || lowerRole.contains('node') || lowerRole.contains('python') || lowerRole.contains('java') || lowerRole.contains('go')) {
       baseQuestions = [
        'Welcome to $company. As a $role, how do you design scalable APIs capable of handling high traffic?',
        'Explain how you enforce data integrity and manage complex database migrations.',
        'What caching strategies would you implement to reduce database load?',
        'How do you manage authentication and securely store user credentials?',
        'Describe a situation where you had to troubleshoot and fix a memory leak or performance bottleneck on the server.',
        'Describe the differences between horizontal and vertical scaling.',
        'How do you implement rate limiting in a microservices architecture?',
        'Explain the CAP theorem and its implications in distributed databases.',
        'What are the best practices for handling long-running background jobs?',
        'How does containerization improve deployment strategies?'
      ];
    } else if (lowerRole.contains('data') || lowerRole.contains('machine learning') || lowerRole.contains('ai')) {
       baseQuestions = [
        'Welcome to $company. As a $role, how do you deal with missing or anomalous data in your datasets?',
        'Explain the trade-offs between picking a complex deep learning model versus a simpler regression model.',
        'How do you deploy and monitor a machine learning model in production?',
        'What metrics do you use to evaluate the performance of classification models?',
        'Describe a time you optimized an ETL pipeline for better performance.',
        'Explain bias-variance tradeoff in machine learning algorithms.',
        'How do you prevent overfitting when working with small datasets?',
        'What are the challenges in building recommendation engines?',
        'How does backpropagation work in deep neural networks?',
        'Describe approaches for NLP tokenization and embedding generation.'
      ];
    } else {
      baseQuestions = [
        'Welcome to $company. As a $role, can you describe how you architect solutions for complex engineering problems?',
        'What are the most critical technical skills needed to succeed as a $role at $company?',
        'How do you ensure code quality, testing, and security in your day-to-day work?',
        'Can you explain a difficult technical concept related to being a $role to a non-engineer?',
        'What modern industry methodologies would you bring to improve our engineering workflows at $company?',
        'How do you handle conflict in architectural decisions with fellow engineers?',
        'Describe a time when you had to migrate legacy systems with zero downtime.',
        'What processes do you implement to ensure reliable CI/CD pipelines?',
        'How do you deal with technical debt while still shipping features quickly?',
        'What makes a 10x engineer different from an average engineer?'
      ];
    }
    
    return baseQuestions.take(limit).toList();
  }
}
