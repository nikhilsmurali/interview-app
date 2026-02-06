class InterviewSession {
  final String id;
  final String userId;
  final String targetCompany;
  final String targetRole;
  final double yearsOfExperience;
  final DateTime createdAt;
  final String status;
  final List<String> questions;

  InterviewSession({
    required this.id,
    required this.userId,
    required this.targetCompany,
    required this.targetRole,
    required this.yearsOfExperience,
    required this.createdAt,
    required this.status,
    this.questions = const [],
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
      'questions': questions,
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
      questions: List<String>.from(map['questions'] ?? []),
    );
  }
}
