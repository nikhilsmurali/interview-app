import 'package:ai_interviewer/features/home/models/interview_session.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InterviewReportScreen extends StatelessWidget {
  final InterviewSession session;

  const InterviewReportScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(session.createdAt);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Interview Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            _buildHeaderCard(dateStr),
            const SizedBox(height: 24),

            // Performance Summary (Hardcoded for now)
            _buildSectionTitle('Performance Summary'),
            const SizedBox(height: 12),
            _buildSummaryCard(),
            const SizedBox(height: 32),

            // Q&A Exchanges
            _buildSectionTitle('Interview Exchanges'),
            const SizedBox(height: 12),
            if (session.exchanges.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('No exchanges recorded for this session.', 
                    style: TextStyle(color: Colors.white54)),
                ),
              )
            else
              ...session.exchanges.asMap().entries.map((entry) {
                return _buildExchangeCard(entry.key + 1, entry.value);
              }),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String dateStr) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
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
                Text(
                  session.targetRole.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  session.targetCompany,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white60, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: const TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Icon(Icons.analytics_outlined, color: Colors.white, size: 30),
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

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Overall Score: 8.5/10',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'The candidate demonstrated strong technical proficiency in the requested domain. Their answers were structured and reflected real-world experience. Key strengths included deep understanding of architectural principles and problem-solving skills.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              _Tag(label: 'Technical Deep-Dive', color: Colors.blue),
              _Tag(label: 'Strong Debugging', color: Colors.green),
              _Tag(label: 'Architecture', color: Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeCard(int index, dynamic exchange) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Q$index',
                  style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            exchange.question,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            'YOUR ANSWER',
            style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            exchange.answer,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          const Text(
            'AI FEEDBACK',
            style: TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            exchange.feedback,
            style: const TextStyle(color: Colors.white60, fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
