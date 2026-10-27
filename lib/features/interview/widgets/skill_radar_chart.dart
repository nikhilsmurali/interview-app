import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:ai_interviewer/features/home/models/interview_session.dart';

class SkillRadarChart extends StatelessWidget {
  final RadarScores radarScores;

  const SkillRadarChart({
    super.key,
    required this.radarScores,
  });

  @override
  Widget build(BuildContext context) {
    final entries = [
      radarScores.coreTechnical,
      radarScores.problemSolving,
      radarScores.communication,
      radarScores.systemArchitecture,
      radarScores.confidence,
    ];

    final labels = [
      'Core Technical',
      'Problem Solving',
      'Communication',
      'System Architecture',
      'Confidence',
    ];

    final icons = [
      Icons.code_rounded,
      Icons.psychology_rounded,
      Icons.record_voice_over_rounded,
      Icons.account_tree_rounded,
      Icons.verified_user_rounded,
    ];

    final colors = [
      Colors.lightBlueAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
      const Color(0xFFFF8A00),
      Colors.amberAccent,
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5A00).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.radar_rounded, color: Color(0xFFFF5A00), size: 20),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Skill Competency Radar",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "5-Dimensional Technical & Soft Skill Breakdown",
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Radar Chart Display
          SizedBox(
            height: 260,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                radarBorderData: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                gridBorderData: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
                tickBorderData: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 0.5),
                tickCount: 4,
                ticksTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 9),
                getTitle: (index, angle) {
                  return RadarChartTitle(
                    text: labels[index],
                    angle: angle,
                  );
                },
                titleTextStyle: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                dataSets: [
                  RadarDataSet(
                    fillColor: const Color(0xFFFF5A00).withValues(alpha: 0.28),
                    borderColor: const Color(0xFFFF5A00),
                    entryRadius: 3.5,
                    borderWidth: 2.5,
                    dataEntries: entries.map((val) => RadarEntry(value: val)).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // Dimension Score Cards
          ...List.generate(5, (index) {
            final score = entries[index];
            final label = labels[index];
            final icon = icons[index];
            final color = colors[index];
            final percent = (score / 10.0).clamp(0.0, 1.0);

            String statusLabel;
            if (score >= 8.5) {
              statusLabel = "Exceptional";
            } else if (score >= 7.0) {
              statusLabel = "Proficient";
            } else if (score >= 5.5) {
              statusLabel = "Competent";
            } else {
              statusLabel = "Developing";
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${score.toStringAsFixed(1)} / 10",
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
