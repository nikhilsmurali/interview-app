import 'package:ai_interviewer/core/services/gemini_service.dart';

void main() async {
  final service = GeminiService();
  final qs = await service.generateInterviewQuestions("Google", "Flutter Developer");
  print(qs);
}
