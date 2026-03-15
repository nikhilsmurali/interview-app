import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_interviewer/core/services/firestore_service.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/home/models/interview_session.dart';
import 'package:intl/intl.dart';

class ConsistencyHeatmap extends StatefulWidget {
  const ConsistencyHeatmap({super.key});

  @override
  State<ConsistencyHeatmap> createState() => _ConsistencyHeatmapState();
}

class _ConsistencyHeatmapState extends State<ConsistencyHeatmap> {
  late Future<List<InterviewSession>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user != null) {
      _reportsFuture = FirestoreService().getInterviewHistory(user.uid);
    } else {
      _reportsFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consistency Tracker',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
          ),
          child: FutureBuilder<List<InterviewSession>>(
            future: _reportsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(color: Color(0xFFFF5A00)),
                  ),
                );
              }

              final reports = snapshot.data ?? [];
              
              final now = DateTime.now();
              // Calculate for the past 365 days
              final startDate = now.subtract(const Duration(days: 364));
              
              // Map counts by YYYY-MM-DD
              final Map<String, int> dailyCounts = {};
              for (final report in reports) {
                final date = report.createdAt;
                if (date.isAfter(startDate.subtract(const Duration(days: 1)))) {
                  final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  dailyCounts[key] = (dailyCounts[key] ?? 0) + 1;
                }
              }

              // Compute stats
              int totalInterviews = 0;
              int activeDays = 0;
              int maxStreak = 0;
              int currentStreak = 0;

              for (int i = 0; i < 365; i++) {
                final date = startDate.add(Duration(days: i));
                final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                final count = dailyCounts[key] ?? 0;
                
                totalInterviews += count;
                if (count > 0) {
                  activeDays++;
                  currentStreak++;
                  if (currentStreak > maxStreak) {
                    maxStreak = currentStreak;
                  }
                } else {
                  currentStreak = 0;
                }
              }

              // Build the grid
              // Dart weekday: 1=Mon, ..., 7=Sun. We want 0=Sun, 1=Mon, ..., 6=Sat
              final int startWeekday = startDate.weekday % 7;
              
              List<Widget> gridColumns = [];
              List<Widget> monthLabels = [];
              List<Widget> currentColumnCells = [];
              int dayIndex = 0;
              int currentMonth = startDate.month;

              // Fill initial empty cells if startDate is not Sunday
              for (int i = 0; i < startWeekday; i++) {
                currentColumnCells.add(const SizedBox(width: 12, height: 12));
                currentColumnCells.add(const SizedBox(height: 4));
              }

              while (dayIndex < 365) {
                final date = startDate.add(Duration(days: dayIndex));
                
                if (date.month != currentMonth) {
                  // Push a month label marker approx where the month changes
                  monthLabels.add(
                    Positioned(
                      left: gridColumns.length * 16.0,
                      child: Text(
                        DateFormat('MMM').format(date),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 10),
                      ),
                    ),
                  );
                  currentMonth = date.month;
                }

                currentColumnCells.add(_buildDayBox(date, dailyCounts));

                // If column is full (7 days), push to grid
                if (currentColumnCells.length == 14) { // 7 cells + 7 sizedbox height spacers (wait we have to be careful with spacing, easiest is to just use a Column with spacing)
                  // Let's reset the logic for a cleaner column build
                }
                dayIndex++;
              }

              // Actually, let's cleanly build columns
              gridColumns.clear();
              monthLabels.clear();
              dayIndex = 0;
              currentMonth = startDate.month;
              
              int colIndex = 0;
              while (dayIndex < 365) {
                List<Widget> columnChildren = [];
                for (int row = 0; row < 7; row++) {
                  if (dayIndex == 0 && row < startWeekday) {
                    columnChildren.add(const SizedBox(width: 12, height: 12));
                  } else if (dayIndex < 365) {
                    final date = startDate.add(Duration(days: dayIndex));
                    
                    if (date.day == 1) {
                      monthLabels.add(
                        Positioned(
                          left: colIndex * 16.0,
                          top: 0,
                          child: Text(
                            DateFormat('MMM').format(date),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 10),
                          ),
                        ),
                      );
                    }

                    columnChildren.add(_buildDayBox(date, dailyCounts));
                    dayIndex++;
                  } else {
                    columnChildren.add(const SizedBox(width: 12, height: 12));
                  }
                }
                gridColumns.add(
                  Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: columnChildren.expand((widget) => [widget, const SizedBox(height: 4)]).toList()..removeLast(),
                    ),
                  )
                );
                colIndex++;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stat Header
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '$totalInterviews ', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                            TextSpan(text: 'interviews in the last year', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14)),
                          ]
                        )
                      ),
                      const SizedBox(width: 16),
                      Wrap(
                        spacing: 16,
                        children: [
                          Text('Total active days: $activeDays', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                          Text('Max streak: $maxStreak', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
                        ]
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Heatmap Scrollable Area
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true, // Scroll to the right end (today)
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Months row
                        SizedBox(
                          height: 16,
                          width: gridColumns.length * 16.0,
                          child: Stack(clipBehavior: Clip.none, children: monthLabels),
                        ),
                        // Grid
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: gridColumns,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Less', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 10)),
                      const SizedBox(width: 6),
                      _buildLegendBox(context, Theme.of(context).colorScheme.onSurface.withOpacity(0.05)),
                      const SizedBox(width: 4),
                      _buildLegendBox(context, const Color(0xFFFF5A00).withOpacity(0.3)),
                      const SizedBox(width: 4),
                      _buildLegendBox(context, const Color(0xFFFF5A00).withOpacity(0.5)),
                      const SizedBox(width: 4),
                      _buildLegendBox(context, const Color(0xFFFF5A00).withOpacity(0.7)),
                      const SizedBox(width: 4),
                      _buildLegendBox(context, const Color(0xFFFF5A00)),
                      const SizedBox(width: 6),
                      Text('More', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 10)),
                    ],
                  ),
                ],
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildDayBox(DateTime date, Map<String, int> dailyCounts) {
    final dateStr = DateFormat('MMM d, yyyy').format(date);
    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final count = dailyCounts[key] ?? 0;

    int level = count > 4 ? 4 : count;
    
    Color color;
    switch (level) {
      case 0:
        color = Theme.of(context).colorScheme.onSurface.withOpacity(0.05);
        break;
      case 1:
        color = const Color(0xFFFF5A00).withOpacity(0.3);
        break;
      case 2:
        color = const Color(0xFFFF5A00).withOpacity(0.5);
        break;
      case 3:
        color = const Color(0xFFFF5A00).withOpacity(0.7);
        break;
      default:
        color = const Color(0xFFFF5A00);
    }

    return Tooltip(
      message: count == 0 
          ? 'No interviews on $dateStr' 
          : '$count interview${count == 1 ? '' : 's'} on $dateStr',
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05)),
        ),
      ),
    );
  }

  Widget _buildLegendBox(BuildContext context, Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05)),
      ),
    );
  }
}
