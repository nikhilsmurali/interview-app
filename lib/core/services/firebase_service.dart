import 'package:firebase_core/firebase_core.dart';
import 'package:ai_interviewer/firebase_options.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("Firebase Initialized successfully");
    } catch (e) {
      debugPrint("Firebase Initialization Failed: $e");
    }
  }
}
