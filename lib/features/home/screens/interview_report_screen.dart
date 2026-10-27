import 'package:fl_chart/fl_chart.dart';
import 'package:ai_interviewer/features/home/models/interview_session.dart';
import 'package:ai_interviewer/features/interview/widgets/skill_radar_chart.dart';
import 'package:ai_interviewer/features/interview/widgets/speech_metrics_card.dart';
import 'package:ai_interviewer/core/services/pdf_report_service.dart';
import 'package:ai_interviewer/core/services/speech_metrics_analyzer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InterviewReportScreen extends StatefulWidget {
  final InterviewSession session;

  const InterviewReportScreen({super.key, required this.session});

  @override
  State<InterviewReportScreen> createState() => _InterviewReportScreenState();
}

class _InterviewReportScreenState extends State<InterviewReportScreen> {
  bool _isDownloadingPdf = false;

  Future<void> _downloadPdfReport() async {
    if (_isDownloadingPdf) return;

    setState(() => _isDownloadingPdf = true);

    try {
      await PdfReportService.generateAndDownloadReport(widget.session);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E1E2C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFFF5A00)),
            ),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Branded PDF Report downloaded successfully!",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("PDF Download Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text("Failed to download PDF: $e"),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final dateStr = DateFormat('MMM d, yyyy').format(session.createdAt);

    // Fallbacks if not computed yet
    final metrics = session.speechMetrics ??
        (session.exchanges.isNotEmpty
            ? SpeechMetricsAnalyzer.analyze(
                answers: session.exchanges.map((e) => e.answer).toList(),
                totalSpeakingSeconds: session.exchanges.length * 45,
              )
            : SpeechMetrics.empty());

    final radar = session.radarScores ??
        RadarScores.fallback(session.overallScore, metrics.articulationScore);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Interview Intelligence Report',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _isDownloadingPdf ? null : _downloadPdfReport,
              icon: _isDownloadingPdf
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded, size: 16),
              label: Text(
                _isDownloadingPdf ? "Generating..." : "Download PDF",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                _buildHeaderCard(dateStr),
                const SizedBox(height: 24),

                // Performance Summary (Bar Chart & Score)
                _buildSectionTitle('Overall Performance Summary'),
                const SizedBox(height: 12),
                _buildSummaryCard(context),
                const SizedBox(height: 28),

                // Skill-Specific Radar Chart (Spider Chart)
                _buildSectionTitle('Skill Competency Radar'),
                const SizedBox(height: 12),
                SkillRadarChart(radarScores: radar),
                const SizedBox(height: 28),

                // Speech Metrics (Filler Words & Speaking Pace)
                _buildSectionTitle('Speech & Communication Intelligence'),
                const SizedBox(height: 12),
                SpeechMetricsCard(metrics: metrics),
                const SizedBox(height: 28),

                // In-Depth AI Review & Study Roadmap
                _buildSectionTitle('Post-Interview AI Review & Roadmap'),
                const SizedBox(height: 12),
                _buildDetailedAnalysisCard(context),
                const SizedBox(height: 28),

                // Q&A Exchanges
                _buildSectionTitle('Interview Exchanges Breakdown'),
                const SizedBox(height: 12),
                if (session.exchanges.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'No exchanges recorded for this session.',
                        style: TextStyle(color: Colors.white38),
                      ),
                    ),
                  )
                else
                  ...session.exchanges.asMap().entries.map((entry) {
                    return _buildExchangeCard(context, entry.key + 1, entry.value);
                  }),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String dateStr) {
    final session = widget.session;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5A00), Color(0xFFFF8A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5A00).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.targetRole.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  session.targetCompany,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(width: 14),
                    const Text("•", style: TextStyle(color: Colors.white54)),
                    const SizedBox(width: 14),
                    const Icon(Icons.bar_chart, color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "${session.difficulty} Difficulty",
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final session = widget.session;
    double averageScore = session.overallScore;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 10),
              Text(
                'Overall Score: ${averageScore.toStringAsFixed(1)} / 10',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: (averageScore >= 8.0
                          ? Colors.greenAccent
                          : (averageScore >= 6.0 ? const Color(0xFFFF8A00) : Colors.redAccent))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (averageScore >= 8.0
                            ? Colors.greenAccent
                            : (averageScore >= 6.0 ? const Color(0xFFFF8A00) : Colors.redAccent))
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  averageScore >= 8.0
                      ? 'Strong Hire'
                      : (averageScore >= 6.0 ? 'Hire' : 'Needs Preparation'),
                  style: TextStyle(
                    color: averageScore >= 8.0
                        ? Colors.greenAccent
                        : (averageScore >= 6.0 ? const Color(0xFFFF8A00) : Colors.redAccent),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Question Performance Breakdown',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Analytics Chart
          if (session.exchanges.isNotEmpty)
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 10,
                  minY: 0,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Q${value.toInt() + 1}',
                              style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value == 0 || value == 10 || value == 5) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(color: Colors.white30, fontSize: 10),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 28,
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: session.exchanges.asMap().entries.map((entry) {
                    final index = entry.key;
                    final exchange = entry.value;
                    double rating = exchange.rating.toDouble();
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: rating,
                          color: rating >= 7
                              ? Colors.greenAccent
                              : (rating >= 4 ? const Color(0xFFFF8A00) : Colors.redAccent),
                          width: 18,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            )
          else
            const Center(
              child: Text("No data to display.", style: TextStyle(color: Colors.white38)),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailedAnalysisCard(BuildContext context) {
    final session = widget.session;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalysisSection(
            title: 'Strong Points & Differentiators',
            icon: Icons.check_circle_outline,
            iconColor: Colors.greenAccent,
            items: session.strongPoints,
          ),
          const Divider(height: 32, color: Colors.white10),
          _buildAnalysisSection(
            title: 'Areas for Improvement',
            icon: Icons.error_outline,
            iconColor: Colors.orangeAccent,
            items: session.weakAreas,
          ),
          const Divider(height: 32, color: Colors.white10),
          _buildAnalysisSection(
            title: 'Actionable Improvement Tips',
            icon: Icons.lightbulb_outline,
            iconColor: Colors.amberAccent,
            items: session.improvementTips,
          ),
          if (session.studyRoadmap.isNotEmpty) ...[
            const Divider(height: 32, color: Colors.white10),
            _buildStudyRoadmapSection(session.studyRoadmap),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Text(
            'No specific data available.',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          )
        else
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("• ", style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildStudyRoadmapSection(List<String> roadmap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.route_rounded, color: Color(0xFFFF5A00), size: 20),
            SizedBox(width: 8),
            Text(
              "Customized Preparation Roadmap",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...roadmap.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final step = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFF5A00).withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5A00).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "M$index",
                    style: const TextStyle(
                      color: Color(0xFFFF8A00),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExchangeCard(BuildContext context, int index, dynamic exchange) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5A00).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Question $index',
                  style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: (exchange.rating >= 7
                          ? Colors.green
                          : (exchange.rating >= 4 ? Colors.orange : Colors.red))
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${exchange.rating}/10',
                  style: TextStyle(
                    color: exchange.rating >= 7
                        ? Colors.greenAccent
                        : (exchange.rating >= 4 ? Colors.orangeAccent : Colors.redAccent),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            exchange.question,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'YOUR ANSWER',
            style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            exchange.answer,
            style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 13.5),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          const Text(
            'AI FEEDBACK',
            style: TextStyle(color: Color(0xFFFF5A00), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            exchange.feedback,
            style: const TextStyle(color: Colors.white60, fontSize: 13, fontStyle: FontStyle.italic, height: 1.4),
          ),
        ],
      ),
    );
  }
}
