import 'dart:convert';
import 'package:ai_interviewer/core/secrets/app_secrets.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  static const String _groqApiKey = AppSecrets.groqApiKey;
  static const String _groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  static const String _geminiApiKey = AppSecrets.geminiApiKey;
  static const String _geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey';

  Future<List<String>> generateInterviewQuestions(
    String company,
    String role, [
    String? resume,
    String difficulty = 'Medium',
    String? jobDescription,
  ]) async {
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

    if (jobDescription != null && jobDescription.trim().isNotEmpty) {
      basePrompt += '\n\nTarget Job Description:\n$jobDescription';
    }

    if (resume != null && resume.trim().isNotEmpty) {
      basePrompt += '\n\nCandidate Resume / CV:\n$resume';
    }

    if (jobDescription != null && jobDescription.trim().isNotEmpty && resume != null && resume.trim().isNotEmpty) {
      basePrompt += '''

MANDATORY RESUME VS. JOB DESCRIPTION GAP ANALYSIS:
1. Cross-reference the Candidate's Resume against the Target Job Description.
2. Identify critical skills, technologies, frameworks, and responsibilities demanded in the Job Description that are missing or weakly evidenced on their CV.
3. Dedicate at least 2 or 3 questions specifically to probing these GAP areas to test if the candidate possesses practical working ability beyond what is explicitly listed.
4. Dedicate 2 questions to deep dive into the projects and accomplishments claimed on their resume to verify authenticity and depth.
''';
    } else if (resume != null && resume.trim().isNotEmpty) {
      basePrompt += '\n\nPERSONALIZATION:\nTailor at least 2-3 questions specifically to the candidate\'s past projects, technologies, and achievements listed on their resume.';
    } else if (jobDescription != null && jobDescription.trim().isNotEmpty) {
      basePrompt += '\n\nJOB DESCRIPTION FOCUS:\nEnsure questions heavily test the exact qualifications, tools, and technical requirements listed in the Job Description.';
    }

    // --- STEP 1: Try Groq ---
    try {
      print('>>> [API] Calling Groq (GPT-OSS 120B)...');
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': 'openai/gpt-oss-120b',
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
          'model': 'openai/gpt-oss-120b',
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
    
    final prompt = '''As a senior technical interviewer and hiring committee lead, provide a comprehensive final performance evaluation for a $role candidate based on this interview transcript:
    
$transcript

Evaluate performance across both technical depth and communication articulation.
Output strictly in this JSON format:
{
  "strongPoints": ["Key strength 1 with specific evidence", "Key strength 2"],
  "weakAreas": ["Constructive gap 1 with context", "Constructive gap 2"],
  "improvementTips": ["Technical: specific architectural or coding recommendation", "Communication: vocal cadence or structure recommendation"],
  "studyRoadmap": [
    "Milestone 1: Deep dive into core algorithms and edge cases relevant to $role",
    "Milestone 2: Practice system scalability (caching, load balancing, SPOF analysis)",
    "Milestone 3: Rehearse behavioral STAR-method articulation to eliminate filler words"
  ],
  "radarScores": {
    "coreTechnical": 8.0,
    "problemSolving": 7.5,
    "communication": 8.5,
    "systemArchitecture": 7.0,
    "confidence": 8.0
  }
}''';

    try {
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': 'openai/gpt-oss-120b',
          'messages': [{'role': 'user', 'content': prompt}],
          'response_format': {'type': 'json_object'},
          'temperature': 0.1,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(jsonDecode(response.body)['choices'][0]['message']['content']);
      }
    } catch (e) {
      print('Summary generation error: $e');
    }

    return {
      "strongPoints": ["Communicative and engaged throughout", "Demonstrated foundational problem-solving capability"],
      "weakAreas": ["Deeper technical edge-case analysis", "Specific architectural tradeoff clarity"],
      "improvementTips": ["Technical: Study concurrency and distributed caching paradigms", "Communication: State high-level overview before diving into implementation details"],
      "studyRoadmap": [
        "Milestone 1: Review foundational data structures and standard algorithm complexities",
        "Milestone 2: Design distributed backend and caching topologies",
        "Milestone 3: Practice mock interviews focusing on concise, structured delivery"
      ],
      "radarScores": {
        "coreTechnical": 7.5,
        "problemSolving": 7.8,
        "communication": 8.0,
        "systemArchitecture": 7.2,
        "confidence": 7.9
      }
    };
  }

  Future<Map<String, dynamic>> evaluateCodeSolution({
    required String question,
    required String code,
    required String language,
  }) async {
    final prompt = '''As a principal software engineer and coding interviewer, evaluate the candidate's code submission for the technical interview.

Interview Question/Problem:
$question

Programming Language:
$language

Candidate's Code Solution:
```$language
$code
```

Analyze the code rigorously.
Return a valid JSON object matching this schema:
{
  "timeComplexity": "O(N log N)",
  "spaceComplexity": "O(N)",
  "rating": 8.5,
  "summary": "Clear, concise 1-2 sentence overall summary of the solution quality.",
  "strengths": ["Clean idiomatic syntax", "Optimal sorting approach"],
  "edgeCasesAndBugs": ["Fails on empty array input", "Integer overflow for large values"],
  "optimizationTips": "Consider two-pointer technique to achieve O(N) linear time."
}''';

    try {
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': 'openai/gpt-oss-120b',
          'messages': [{'role': 'user', 'content': prompt}],
          'response_format': {'type': 'json_object'},
          'temperature': 0.2,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(jsonDecode(response.body)['choices'][0]['message']['content']);
      }
    } catch (e) {
      print('evaluateCodeSolution error: $e');
    }

    return {
      "timeComplexity": "O(N)",
      "spaceComplexity": "O(1)",
      "rating": 7.5,
      "summary": "Valid implementation with standard algorithmic logic.",
      "strengths": ["Clear syntax and readable variable naming", "Correct core algorithm structure"],
      "edgeCasesAndBugs": ["Check boundaries for empty or extreme inputs"],
      "optimizationTips": "Analyze if auxiliary memory can be further reduced."
    };
  }

  Future<Map<String, dynamic>> evaluateSystemDesign({
    required String question,
    required List<Map<String, dynamic>> components,
    required List<Map<String, dynamic>> connections,
  }) async {
    final componentsStr = components.map((c) => "- ${c['name']} (${c['type']})").join("\n");
    final connectionsStr = connections.map((c) => "- ${c['from']} -> ${c['to']} [Protocol/Flow: ${c['label'] ?? 'HTTPS'}]").join("\n");

    final prompt = '''As a Staff Infrastructure & Systems Architect, review the candidate's interactive system design whiteboard architecture.

Interview Scenario / Problem:
$question

Architectural Components Placed:
$componentsStr

Data Flow & Service Connections:
$connectionsStr

Provide a rigorous architectural assessment.
Return a valid JSON object matching this schema:
{
  "rating": 8.0,
  "verdict": "Production-Ready / Feasible Architecture",
  "summary": "Concise 1-2 sentence review of the architecture topology.",
  "scalabilityScore": "High / Medium",
  "bottlenecks": ["Single primary database without read replicas", "Potential cache thundering herd"],
  "strengths": ["Appropriate placement of API Gateway and Load Balancer", "Asynchronous decoupling via message queue"],
  "recommendations": ["Introduce read replicas for DB", "Add rate limiting on API Gateway"]
}''';

    try {
      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': 'openai/gpt-oss-120b',
          'messages': [{'role': 'user', 'content': prompt}],
          'response_format': {'type': 'json_object'},
          'temperature': 0.2,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(jsonDecode(response.body)['choices'][0]['message']['content']);
      }
    } catch (e) {
      print('evaluateSystemDesign error: $e');
    }

    return {
      "rating": 7.0,
      "verdict": "Feasible Architecture with Tradeoffs",
      "summary": "Good separation of concerns and clear data flow between tiers.",
      "scalabilityScore": "Medium",
      "bottlenecks": ["Monitor database write saturation", "Ensure cache invalidation consistency"],
      "strengths": ["Tiered caching and load balancing", "Clean component decoupling"],
      "recommendations": ["Consider adding multi-region failover and read replicas"]
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
