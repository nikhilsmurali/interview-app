import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai_interviewer/features/home/models/candidate_profile.dart';
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
}
