import 'package:ai_interviewer/features/interview/models/interview_exchange.dart';
import 'package:ai_interviewer/core/services/speech_metrics_analyzer.dart';

class RadarScores {
  final double coreTechnical;
  final double problemSolving;
  final double communication;
  final double systemArchitecture;
  final double confidence;

  const RadarScores({
    required this.coreTechnical,
    required this.problemSolving,
    required this.communication,
    required this.systemArchitecture,
    required this.confidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'coreTechnical': coreTechnical,
      'problemSolving': problemSolving,
      'communication': communication,
      'systemArchitecture': systemArchitecture,
      'confidence': confidence,
    };
  }

  factory RadarScores.fromMap(Map<String, dynamic> map) {
    return RadarScores(
      coreTechnical: (map['coreTechnical'] ?? 7.5).toDouble(),
      problemSolving: (map['problemSolving'] ?? 7.5).toDouble(),
      communication: (map['communication'] ?? 8.0).toDouble(),
      systemArchitecture: (map['systemArchitecture'] ?? 7.0).toDouble(),
      confidence: (map['confidence'] ?? 8.0).toDouble(),
    );
  }

  factory RadarScores.fallback(double overallScore, double articulation) {
    final base = overallScore.clamp(3.0, 9.5);
    return RadarScores(
      coreTechnical: double.parse(base.toStringAsFixed(1)),
      problemSolving: double.parse(((base + 0.4).clamp(1.0, 10.0)).toStringAsFixed(1)),
      communication: double.parse(articulation.clamp(1.0, 10.0).toStringAsFixed(1)),
      systemArchitecture: double.parse(((base - 0.4).clamp(1.0, 10.0)).toStringAsFixed(1)),
      confidence: double.parse(((base + 0.2).clamp(1.0, 10.0)).toStringAsFixed(1)),
    );
  }
}

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
  final List<String> strongPoints;
  final List<String> weakAreas;
  final List<String> improvementTips;
  final List<String> studyRoadmap;
  final SpeechMetrics? speechMetrics;
  final RadarScores? radarScores;

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
    this.strongPoints = const [],
    this.weakAreas = const [],
    this.improvementTips = const [],
    this.studyRoadmap = const [],
    this.speechMetrics,
    this.radarScores,
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
      'strongPoints': strongPoints,
      'weakAreas': weakAreas,
      'improvementTips': improvementTips,
      'studyRoadmap': studyRoadmap,
      'speechMetrics': speechMetrics?.toMap(),
      'radarScores': radarScores?.toMap(),
    };
  }

  factory InterviewSession.fromMap(Map<String, dynamic> map) {
    final exchangesList = (map['exchanges'] as List<dynamic>?)
            ?.map((e) => InterviewExchange.fromMap(e))
            .toList() ??
        [];

    final score = (map['overallScore'] ?? 0).toDouble();

    SpeechMetrics? metrics;
    if (map['speechMetrics'] != null) {
      metrics = SpeechMetrics.fromMap(Map<String, dynamic>.from(map['speechMetrics']));
    } else if (exchangesList.isNotEmpty) {
      metrics = SpeechMetricsAnalyzer.analyze(
        answers: exchangesList.map((e) => e.answer).toList(),
        totalSpeakingSeconds: exchangesList.length * 45,
      );
    }

    RadarScores? radar;
    if (map['radarScores'] != null) {
      radar = RadarScores.fromMap(Map<String, dynamic>.from(map['radarScores']));
    } else {
      radar = RadarScores.fallback(score, metrics?.articulationScore ?? 8.0);
    }

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
      exchanges: exchangesList,
      overallScore: score,
      feedbackSummary: map['feedbackSummary'] ?? '',
      strongPoints: List<String>.from(map['strongPoints'] ?? []),
      weakAreas: List<String>.from(map['weakAreas'] ?? []),
      improvementTips: List<String>.from(map['improvementTips'] ?? []),
      studyRoadmap: List<String>.from(map['studyRoadmap'] ?? []),
      speechMetrics: metrics,
      radarScores: radar,
    );
  }
}
