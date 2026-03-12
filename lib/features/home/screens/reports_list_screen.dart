import 'package:ai_interviewer/core/services/firestore_service.dart';
import 'package:ai_interviewer/features/auth/services/auth_service.dart';
import 'package:ai_interviewer/features/home/models/interview_session.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_interviewer/features/home/screens/interview_report_screen.dart';
import 'package:intl/intl.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Interview History', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<InterviewSession>>(
        future: _reportsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return const Center(
              child: Text(
                'No interviews found.\nStart a new one!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(report.createdAt);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    child: const Icon(Icons.assignment_turned_in, color: Color(0xFF6366F1)),
                  ),
                  title: Text(
                    report.targetRole,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(report.targetCompany, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InterviewReportScreen(session: report),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
