import 'package:ai_interviewer/core/services/openai_service.dart';

void main() async {
  final service = OpenAIService();
  final qs = await service.generateInterviewQuestions("Google", "Flutter Developer");
  print(qs);
}
