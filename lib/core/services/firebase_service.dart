import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static Future<void> initialize() async {
     // TODO: Replace with actual config if not using generated firebase_options.dart
     // For now, we assume the user has placed google-services.json / GoogleService-Info.plist
    try {
      if (kIsWeb) {
        // Web initialization requires options
        // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
         debugPrint("Firebase Web Init skipped (requires options)");
      } else {
        await Firebase.initializeApp();
      }
      debugPrint("Firebase Initialized");
    } catch (e) {
      debugPrint("Firebase Initialization Failed: $e");
    }
  }
}
