import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:ai_interviewer/core/utils/file_saver.dart';
import 'package:ai_interviewer/features/home/models/interview_session.dart';

class PdfReportService {
  /// Sanitize text for standard Type 1 Helvetica font (which only accepts ASCII / Latin-1)
  static String _cleanText(String? input) {
    if (input == null || input.isEmpty) return '';
    return input
        .replaceAll('•', '-')
        .replaceAll('→', '>')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('…', '...')
        .replaceAll(RegExp(r'[^\x00-\x7F]'), ' ')
        .trim();
  }

  static Future<void> generateAndDownloadReport(InterviewSession session) async {
    final document = PdfDocument();
    document.pageSettings.margins.all = 36; // 0.5 inch margins

    // Standard Helvetica Fonts
    final titleFont = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final sectionTitleFont = PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold);
    final subHeaderFont = PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold);
    final bodyFont = PdfStandardFont(PdfFontFamily.helvetica, 9.5);
    final boldBodyFont = PdfStandardFont(PdfFontFamily.helvetica, 9.5, style: PdfFontStyle.bold);
    final smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final smallBoldFont = PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold);

    // Color Palette
    final primaryColor = PdfColor(255, 90, 0); // #FF5A00 Brand Orange
    final darkColor = PdfColor(20, 20, 30);
    final mutedColor = PdfColor(110, 110, 130);
    final lightBgColor = PdfColor(248, 249, 252);
    final borderColor = PdfColor(220, 224, 235);
    final greenColor = PdfColor(40, 160, 80);

    // Add first page
    PdfPage currentPage = document.pages.add();
    PdfGraphics graphics = currentPage.graphics;
    final pageSize = currentPage.getClientSize();

    double y = 0;

    void checkPageBreak(double requiredHeight) {
      if (y + requiredHeight > pageSize.height - 30) {
        currentPage = document.pages.add();
        graphics = currentPage.graphics;
        y = 0;
      }
    }

    // 1. TOP BRAND HEADER BANNER
    final headerRect = Rect.fromLTWH(0, y, pageSize.width, 70);
    graphics.drawRectangle(
      brush: PdfSolidBrush(darkColor),
      bounds: headerRect,
    );

    // Brand Accent Bar
    graphics.drawRectangle(
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(0, y, 6, 70),
    );

    // Header Titles
    graphics.drawString(
      "AI INTERVIEW INTELLIGENCE REPORT",
      PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(16, y + 10, pageSize.width - 120, 14),
    );

    final cleanRole = _cleanText(session.targetRole);
    final cleanCompany = _cleanText(session.targetCompany);

    graphics.drawString(
      "$cleanRole | $cleanCompany",
      titleFont,
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      bounds: Rect.fromLTWH(16, y + 26, pageSize.width - 130, 24),
    );

    final dateFormatted = DateFormat('MMMM d, yyyy').format(session.createdAt);
    graphics.drawString(
      "Session Date: $dateFormatted  |  Difficulty: ${session.difficulty}",
      smallFont,
      brush: PdfSolidBrush(PdfColor(200, 200, 215)),
      bounds: Rect.fromLTWH(16, y + 50, pageSize.width - 130, 14),
    );

    // Score Badge in Header (Right Side)
    final badgeRect = Rect.fromLTWH(pageSize.width - 95, y + 10, 85, 50);
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(35, 35, 50)),
      pen: PdfPen(primaryColor, width: 1.2),
      bounds: badgeRect,
    );

    graphics.drawString(
      "OVERALL SCORE",
      PdfStandardFont(PdfFontFamily.helvetica, 6.5, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(primaryColor),
      bounds: Rect.fromLTWH(badgeRect.left, badgeRect.top + 6, badgeRect.width, 10),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    graphics.drawString(
      "${session.overallScore.toStringAsFixed(1)} / 10",
      PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      bounds: Rect.fromLTWH(badgeRect.left, badgeRect.top + 18, badgeRect.width, 18),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    String hireRecommendation = session.overallScore >= 8.0
        ? "Strong Hire"
        : (session.overallScore >= 6.5 ? "Hire" : "Needs Review");
    graphics.drawString(
      hireRecommendation,
      smallBoldFont,
      brush: PdfSolidBrush(session.overallScore >= 6.5 ? greenColor : primaryColor),
      bounds: Rect.fromLTWH(badgeRect.left, badgeRect.top + 36, badgeRect.width, 10),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    y += 82;

    // 2. RADAR & 5-DIMENSION COMPETENCY BREAKDOWN TABLE
    graphics.drawString(
      "1. Skill Competency & Radar Dimensions",
      sectionTitleFont,
      brush: PdfSolidBrush(darkColor),
      bounds: Rect.fromLTWH(0, y, pageSize.width, 18),
    );
    y += 22;

    final radar = session.radarScores ??
        RadarScores.fallback(session.overallScore, session.speechMetrics?.articulationScore ?? 8.0);

    final radarData = [
      {"dim": "Core Technical Knowledge", "score": radar.coreTechnical, "desc": "Algorithmic accuracy, language mastery, domain depth"},
      {"dim": "Problem Solving & Analytical", "score": radar.problemSolving, "desc": "Handling edge cases, logic decomposition, adaptability"},
      {"dim": "Communication & Articulation", "score": radar.communication, "desc": "Clarity of delivery, minimal fillers, structured answers"},
      {"dim": "System Architecture & Scalability", "score": radar.systemArchitecture, "desc": "Component separation, distributed trade-offs, SPOF awareness"},
      {"dim": "Confidence & Professional Presence", "score": radar.confidence, "desc": "Eye contact, composure under follow-ups, vocal conviction"},
    ];

    final colWidths = [160.0, 60.0, pageSize.width - 220.0];
    
    // Header row
    graphics.drawRectangle(
      brush: PdfSolidBrush(lightBgColor),
      pen: PdfPen(borderColor),
      bounds: Rect.fromLTWH(0, y, pageSize.width, 20),
    );
    graphics.drawString("Evaluation Dimension", smallBoldFont, brush: PdfSolidBrush(darkColor), bounds: Rect.fromLTWH(8, y + 5, colWidths[0] - 8, 14));
    graphics.drawString("Score / 10", smallBoldFont, brush: PdfSolidBrush(darkColor), bounds: Rect.fromLTWH(colWidths[0] + 8, y + 5, colWidths[1] - 8, 14));
    graphics.drawString("Assessment Criteria & Observations", smallBoldFont, brush: PdfSolidBrush(darkColor), bounds: Rect.fromLTWH(colWidths[0] + colWidths[1] + 8, y + 5, colWidths[2] - 8, 14));
    y += 20;

    for (final row in radarData) {
      final double score = (row['score'] as num).toDouble();
      graphics.drawRectangle(
        pen: PdfPen(borderColor),
        bounds: Rect.fromLTWH(0, y, pageSize.width, 22),
      );
      graphics.drawString(row['dim'] as String, bodyFont, brush: PdfSolidBrush(darkColor), bounds: Rect.fromLTWH(8, y + 5, colWidths[0] - 8, 14));
      
      final scoreColor = score >= 8.0 ? greenColor : (score >= 6.5 ? primaryColor : mutedColor);
      graphics.drawString("${score.toStringAsFixed(1)} / 10", boldBodyFont, brush: PdfSolidBrush(scoreColor), bounds: Rect.fromLTWH(colWidths[0] + 8, y + 5, colWidths[1] - 8, 14));
      graphics.drawString(row['desc'] as String, smallFont, brush: PdfSolidBrush(mutedColor), bounds: Rect.fromLTWH(colWidths[0] + colWidths[1] + 8, y + 6, colWidths[2] - 8, 14));
      y += 22;
    }

    y += 16;

    // 3. SPEECH METRICS & ARTICULATION INTELLIGENCE
    final metrics = session.speechMetrics;
    if (metrics != null) {
      checkPageBreak(80);
      graphics.drawString(
        "2. Speech & Articulation Intelligence",
        sectionTitleFont,
        brush: PdfSolidBrush(darkColor),
        bounds: Rect.fromLTWH(0, y, pageSize.width, 18),
      );
      y += 22;

      const speechBoxHeight = 54.0;
      graphics.drawRectangle(
        brush: PdfSolidBrush(lightBgColor),
        pen: PdfPen(borderColor),
        bounds: Rect.fromLTWH(0, y, pageSize.width, speechBoxHeight),
      );

      final thirdWidth = pageSize.width / 3.0;

      // Metric 1: Speaking Pace
      graphics.drawString("Speaking Pace", smallBoldFont, brush: PdfSolidBrush(darkColor), bounds: Rect.fromLTWH(12, y + 8, thirdWidth - 20, 12));
      graphics.drawString("${metrics.wordsPerMinute.toInt()} WPM", PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold), brush: PdfSolidBrush(primaryColor), bounds: Rect.fromLTWH(12, y + 22, thirdWidth - 20, 16));
      graphics.drawString(_cleanText(metrics.paceEvaluation), smallFont, brush: PdfSolidBrush(mutedColor), bounds: Rect.fromLTWH(12, y + 38, thirdWidth - 20, 12));

      // Metric 2: Filler Words
      graphics.drawString("Filler Words Count", smallBoldFont, brush: PdfSolidBrush(darkColor), bounds: Rect.fromLTWH(thirdWidth + 12, y + 8, thirdWidth - 20, 12));
      graphics.drawString("${metrics.totalFillerWords} detected", PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold), brush: PdfSolidBrush(metrics.totalFillerWords <= 4 ? greenColor : primaryColor), bounds: Rect.fromLTWH(thirdWidth + 12, y + 22, thirdWidth - 20, 16));
      final breakdownStr = metrics.fillerBreakdown.isEmpty ? "Zero verbal fillers" : metrics.fillerBreakdown.entries.map((e) => '"${e.key}": ${e.value}').join(', ');
      graphics.drawString(_cleanText(breakdownStr), smallFont, brush: PdfSolidBrush(mutedColor), bounds: Rect.fromLTWH(thirdWidth + 12, y + 38, thirdWidth - 20, 12));

      // Metric 3: Articulation Rating
      graphics.drawString("Fluency & Articulation", smallBoldFont, brush: PdfSolidBrush(darkColor), bounds: Rect.fromLTWH(thirdWidth * 2 + 12, y + 8, thirdWidth - 20, 12));
      graphics.drawString("${metrics.articulationScore} / 10", PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold), brush: PdfSolidBrush(greenColor), bounds: Rect.fromLTWH(thirdWidth * 2 + 12, y + 22, thirdWidth - 20, 16));
      graphics.drawString("Density: ${metrics.fillerDensityPercent}% of spoken words", smallFont, brush: PdfSolidBrush(mutedColor), bounds: Rect.fromLTWH(thirdWidth * 2 + 12, y + 38, thirdWidth - 20, 12));

      y += speechBoxHeight + 18;
    }

    // 4. EXECUTIVE AI FEEDBACK & STUDY ROADMAP
    checkPageBreak(120);
    graphics.drawString(
      "3. AI Executive Review & Study Roadmap",
      sectionTitleFont,
      brush: PdfSolidBrush(darkColor),
      bounds: Rect.fromLTWH(0, y, pageSize.width, 18),
    );
    y += 22;

    // Strong Points
    graphics.drawString("Key Strengths & Differentiators:", subHeaderFont, brush: PdfSolidBrush(greenColor), bounds: Rect.fromLTWH(0, y, pageSize.width, 14));
    y += 16;
    for (final point in session.strongPoints) {
      checkPageBreak(18);
      graphics.drawString("- ${_cleanText(point)}", bodyFont, brush: PdfSolidBrush(darkColor), bounds: Rect.fromLTWH(10, y, pageSize.width - 20, 16));
      y += 16;
    }
    y += 8;

    // Areas for Improvement
    checkPageBreak(30);
    graphics.drawString("Constructive Feedback & Gaps:", subHeaderFont, brush: PdfSolidBrush(primaryColor), bounds: Rect.fromLTWH(0, y, pageSize.width, 14));
    y += 16;
    for (final area in session.weakAreas) {
      checkPageBreak(18);
      graphics.drawString("- ${_cleanText(area)}", bodyFont, brush: PdfSolidBrush(darkColor), bounds: Rect.fromLTWH(10, y, pageSize.width - 20, 16));
      y += 16;
    }
    y += 8;

    // Study Roadmap
    if (session.studyRoadmap.isNotEmpty) {
      checkPageBreak(30);
      graphics.drawString("Recommended Preparation Roadmap:", subHeaderFont, brush: PdfSolidBrush(darkColor), bounds: Rect.fromLTWH(0, y, pageSize.width, 14));
      y += 16;
      for (final milestone in session.studyRoadmap) {
        checkPageBreak(20);
        graphics.drawString("> ${_cleanText(milestone)}", boldBodyFont, brush: PdfSolidBrush(primaryColor), bounds: Rect.fromLTWH(10, y, pageSize.width - 20, 16));
        y += 16;
      }
      y += 8;
    }

    y += 12;

    // 5. QUESTION-BY-QUESTION TRANSCRIPT BREAKDOWN
    checkPageBreak(80);
    graphics.drawString(
      "4. Complete Interview Question & Answer Exchanges",
      sectionTitleFont,
      brush: PdfSolidBrush(darkColor),
      bounds: Rect.fromLTWH(0, y, pageSize.width, 18),
    );
    y += 22;

    int qIndex = 1;
    for (final exchange in session.exchanges) {
      checkPageBreak(90);

      // Card Header
      graphics.drawRectangle(
        brush: PdfSolidBrush(lightBgColor),
        pen: PdfPen(borderColor),
        bounds: Rect.fromLTWH(0, y, pageSize.width, 20),
      );

      graphics.drawString(
        "Question $qIndex",
        smallBoldFont,
        brush: PdfSolidBrush(primaryColor),
        bounds: Rect.fromLTWH(8, y + 5, 100, 12),
      );

      final ratingColor = exchange.rating >= 7 ? greenColor : (exchange.rating >= 4 ? primaryColor : mutedColor);
      graphics.drawString(
        "Rating: ${exchange.rating} / 10",
        smallBoldFont,
        brush: PdfSolidBrush(ratingColor),
        bounds: Rect.fromLTWH(pageSize.width - 90, y + 5, 80, 12),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      y += 24;

      // Question text
      final cleanQ = _cleanText(exchange.question);
      graphics.drawString(
        "Q: $cleanQ",
        boldBodyFont,
        brush: PdfSolidBrush(darkColor),
        bounds: Rect.fromLTWH(6, y, pageSize.width - 12, 28),
      );
      y += 30;

      // Candidate's Answer (trimmed if needed)
      final rawAnswer = exchange.answer.length > 250
          ? "${exchange.answer.substring(0, 247)}..."
          : exchange.answer;
      final cleanAnswer = _cleanText(rawAnswer);

      graphics.drawString(
        "Candidate's Response:",
        smallBoldFont,
        brush: PdfSolidBrush(mutedColor),
        bounds: Rect.fromLTWH(6, y, pageSize.width - 12, 12),
      );
      y += 14;

      graphics.drawString(
        cleanAnswer,
        bodyFont,
        brush: PdfSolidBrush(darkColor),
        bounds: Rect.fromLTWH(12, y, pageSize.width - 24, 30),
      );
      y += 32;

      // AI Feedback
      final cleanFeedback = _cleanText(exchange.feedback);
      graphics.drawString(
        "AI Evaluator Feedback: $cleanFeedback",
        PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.italic),
        brush: PdfSolidBrush(primaryColor),
        bounds: Rect.fromLTWH(6, y, pageSize.width - 12, 24),
      );
      y += 28;

      // Divider line
      graphics.drawLine(
        PdfPen(borderColor),
        Offset(0, y),
        Offset(pageSize.width, y),
      );
      y += 12;

      qIndex++;
    }

    // FOOTER ON ALL PAGES
    for (int i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final pSize = page.getClientSize();
      page.graphics.drawString(
        "AI Interviewer Intelligence | Confidential Candidate Report | Page ${i + 1} of ${document.pages.count}",
        PdfStandardFont(PdfFontFamily.helvetica, 7.5),
        brush: PdfSolidBrush(mutedColor),
        bounds: Rect.fromLTWH(0, pSize.height - 15, pSize.width, 12),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
    }

    // Save and Trigger Download
    final bytes = await document.save();
    document.dispose();

    final safeRole = cleanRole.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
    final fileName = "Interview_Report_${safeRole}_${DateFormat('yyyyMMdd').format(session.createdAt)}.pdf";

    await FileSaver.savePdfFile(bytes, fileName);
  }
}
