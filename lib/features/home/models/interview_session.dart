import 'package:ai_interviewer/features/interview/models/interview_exchange.dart';

class InterviewSession {
  final String id;
  final String userId;
  final String targetCompany;
  final String targetRole;
  final double yearsOfExperience;
  final DateTime createdAt;
  final String status;
  final String difficulty;
  final List<String> questions;
  final List<InterviewExchange> exchanges;
  final double overallScore;
  final String feedbackSummary;

  InterviewSession({
    required this.id,
    required this.userId,
    required this.targetCompany,
    required this.targetRole,
    required this.yearsOfExperience,
    required this.createdAt,
    required this.status,
    this.difficulty = 'Medium',
    this.questions = const [],
    this.exchanges = const [],
    this.overallScore = 0.0,
    this.feedbackSummary = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'targetCompany': targetCompany,
      'targetRole': targetRole,
      'yearsOfExperience': yearsOfExperience,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'difficulty': difficulty,
      'questions': questions,
      'exchanges': exchanges.map((e) => e.toMap()).toList(),
      'overallScore': overallScore,
      'feedbackSummary': feedbackSummary,
    };
  }

  factory InterviewSession.fromMap(Map<String, dynamic> map) {
    return InterviewSession(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      targetCompany: map['targetCompany'] ?? '',
      targetRole: map['targetRole'] ?? '',
      yearsOfExperience: (map['yearsOfExperience'] ?? 0).toDouble(),
      createdAt: DateTime.parse(map['createdAt']),
      status: map['status'] ?? 'initiated',
      difficulty: map['difficulty'] ?? 'Medium',
      questions: List<String>.from(map['questions'] ?? []),
      exchanges: (map['exchanges'] as List<dynamic>?)
              ?.map((e) => InterviewExchange.fromMap(e))
              .toList() ??
          [],
      overallScore: (map['overallScore'] ?? 0).toDouble(),
      feedbackSummary: map['feedbackSummary'] ?? '',
    );
  }
}
