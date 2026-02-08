class InterviewExchange {
  final String question;
  final String answer;
  final String feedback;
  final DateTime timestamp;

  InterviewExchange({
    required this.question,
    required this.answer,
    required this.feedback,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
      'feedback': feedback,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory InterviewExchange.fromMap(Map<String, dynamic> map) {
    return InterviewExchange(
      question: map['question'] ?? '',
      answer: map['answer'] ?? '',
      feedback: map['feedback'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}
