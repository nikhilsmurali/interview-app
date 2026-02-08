import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai_interviewer/features/home/models/candidate_profile.dart';
import 'package:ai_interviewer/features/home/models/interview_session.dart';

import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveProfile(CandidateProfile profile) async {
    try {
      await _db.collection('users').doc(profile.uid).set(profile.toMap());
    } catch (e) {
      debugPrint("Error saving profile: $e");
      rethrow;
    }
  }

  Future<CandidateProfile?> getProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return CandidateProfile.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint("Error getting profile: $e");
      return null;
    }
  }

  Future<void> startNewInterview(InterviewSession session) async {
    try {
      await _db
          .collection('users')
          .doc(session.userId)
          .collection('interviews')
          .doc(session.id)
          .set(session.toMap());
      debugPrint("Interview started! Stored in: users/${session.userId}/interviews/${session.id}");
      debugPrint("Data: ${session.toMap()}");
    } catch (e) {
      debugPrint("Error starting interview: $e");
      rethrow;
    }
  }

  Future<void> updateInterviewQuestions(String userId, String interviewId, List<String> questions) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('interviews')
          .doc(interviewId)
          .update({'questions': questions});
    } catch (e) {
      debugPrint("Error updating questions: $e");
      rethrow;
    }
  }
  Future<void> updateInterviewExchanges(String userId, String interviewId, List<Map<String, dynamic>> exchanges) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('interviews')
          .doc(interviewId)
          .update({'exchanges': exchanges});
    } catch (e) {
      debugPrint("Error updating exchanges: $e");
      rethrow;
    }
  }
}

