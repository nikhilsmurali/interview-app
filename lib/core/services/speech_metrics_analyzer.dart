class SpeechMetrics {
  final int totalWords;
  final int totalFillerWords;
  final Map<String, int> fillerBreakdown;
  final double wordsPerMinute;
  final double articulationScore;
  final String paceEvaluation;
  final double fillerDensityPercent;

  const SpeechMetrics({
    required this.totalWords,
    required this.totalFillerWords,
    required this.fillerBreakdown,
    required this.wordsPerMinute,
    required this.articulationScore,
    required this.paceEvaluation,
    required this.fillerDensityPercent,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalWords': totalWords,
      'totalFillerWords': totalFillerWords,
      'fillerBreakdown': fillerBreakdown,
      'wordsPerMinute': wordsPerMinute,
      'articulationScore': articulationScore,
      'paceEvaluation': paceEvaluation,
      'fillerDensityPercent': fillerDensityPercent,
    };
  }

  factory SpeechMetrics.fromMap(Map<String, dynamic> map) {
    return SpeechMetrics(
      totalWords: (map['totalWords'] ?? 0) as int,
      totalFillerWords: (map['totalFillerWords'] ?? 0) as int,
      fillerBreakdown: Map<String, int>.from(map['fillerBreakdown'] ?? {}),
      wordsPerMinute: (map['wordsPerMinute'] ?? 0.0).toDouble(),
      articulationScore: (map['articulationScore'] ?? 8.0).toDouble(),
      paceEvaluation: (map['paceEvaluation'] ?? 'Optimal') as String,
      fillerDensityPercent: (map['fillerDensityPercent'] ?? 0.0).toDouble(),
    );
  }

  factory SpeechMetrics.empty() {
    return const SpeechMetrics(
      totalWords: 0,
      totalFillerWords: 0,
      fillerBreakdown: {},
      wordsPerMinute: 135.0,
      articulationScore: 8.5,
      paceEvaluation: 'Optimal (120-160 WPM)',
      fillerDensityPercent: 0.0,
    );
  }
}

class SpeechMetricsAnalyzer {
  static const List<String> targetFillerWords = [
    'um',
    'uh',
    'er',
    'ah',
    'like',
    'basically',
    'actually',
    'you know',
    'sort of',
    'kind of',
    'i mean',
    'literally',
  ];

  static SpeechMetrics analyze({
    required List<String> answers,
    required int totalSpeakingSeconds,
  }) {
    final combinedText = answers.join(' ').toLowerCase();
    if (combinedText.trim().isEmpty) {
      return SpeechMetrics.empty();
    }

    final words = combinedText
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final totalWords = words.length;

    // Detect filler words
    final Map<String, int> breakdown = {};
    int totalFillers = 0;

    for (final filler in targetFillerWords) {
      final regex = RegExp(r'\b' + RegExp.escape(filler) + r'\b');
      final matches = regex.allMatches(combinedText).length;
      if (matches > 0) {
        breakdown[filler] = matches;
        totalFillers += matches;
      }
    }

    // Calculate WPM
    final durationMinutes = totalSpeakingSeconds > 0
        ? totalSpeakingSeconds / 60.0
        : (totalWords / 135.0); // fallback heuristic if duration unavailable

    double wpm = durationMinutes > 0 ? (totalWords / durationMinutes) : 135.0;
    if (wpm.isNaN || wpm.isInfinite || wpm <= 0) {
      wpm = 135.0;
    }
    // Cap wpm realistically for presentation
    wpm = wpm.clamp(50.0, 240.0);

    // Pace evaluation
    String paceEvaluation;
    if (wpm < 110) {
      paceEvaluation = 'Deliberate & Measured (<110 WPM)';
    } else if (wpm <= 165) {
      paceEvaluation = 'Optimal Pace (120-160 WPM)';
    } else {
      paceEvaluation = 'Fast-Paced (>165 WPM)';
    }

    // Filler density %
    final fillerDensity = totalWords > 0 ? (totalFillers / totalWords) * 100 : 0.0;

    // Articulation Score out of 10
    // Baseline: 9.5
    // Deduct for high filler density
    double score = 9.5;
    if (fillerDensity > 6.0) {
      score -= 3.0;
    } else if (fillerDensity > 3.5) {
      score -= 2.0;
    } else if (fillerDensity > 1.5) {
      score -= 1.0;
    }

    // Deduct slightly for overly rushed or extremely slow speech
    if (wpm > 185 || wpm < 85) {
      score -= 0.8;
    }

    score = score.clamp(3.0, 10.0);

    return SpeechMetrics(
      totalWords: totalWords,
      totalFillerWords: totalFillers,
      fillerBreakdown: breakdown,
      wordsPerMinute: double.parse(wpm.toStringAsFixed(1)),
      articulationScore: double.parse(score.toStringAsFixed(1)),
      paceEvaluation: paceEvaluation,
      fillerDensityPercent: double.parse(fillerDensity.toStringAsFixed(1)),
    );
  }
}
