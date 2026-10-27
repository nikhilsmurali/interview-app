// File generated for Firebase configuration.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA9OkMW4SbRKbKxvM9Rb4IuXc2k2Li90Eo',
    appId: '1:849266316381:web:5c19b05d68cc30cab4a9b4',
    messagingSenderId: '849266316381',
    projectId: 'ai-interviewer-2ce7d',
    authDomain: 'ai-interviewer-2ce7d.firebaseapp.com',
    storageBucket: 'ai-interviewer-2ce7d.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA9OkMW4SbRKbKxvM9Rb4IuXc2k2Li90Eo',
    appId: '1:849266316381:android:5c19b05d68cc30cab4a9b4',
    messagingSenderId: '849266316381',
    projectId: 'ai-interviewer-2ce7d',
    storageBucket: 'ai-interviewer-2ce7d.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA9OkMW4SbRKbKxvM9Rb4IuXc2k2Li90Eo',
    appId: '1:849266316381:web:5c19b05d68cc30cab4a9b4',
    messagingSenderId: '849266316381',
    projectId: 'ai-interviewer-2ce7d',
    authDomain: 'ai-interviewer-2ce7d.firebaseapp.com',
    storageBucket: 'ai-interviewer-2ce7d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA9OkMW4SbRKbKxvM9Rb4IuXc2k2Li90Eo',
    appId: '1:849266316381:ios:5c19b05d68cc30cab4a9b4',
    messagingSenderId: '849266316381',
    projectId: 'ai-interviewer-2ce7d',
    storageBucket: 'ai-interviewer-2ce7d.firebasestorage.app',
    iosBundleId: 'com.example.aiInterviewer',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA9OkMW4SbRKbKxvM9Rb4IuXc2k2Li90Eo',
    appId: '1:849266316381:ios:5c19b05d68cc30cab4a9b4',
    messagingSenderId: '849266316381',
    projectId: 'ai-interviewer-2ce7d',
    storageBucket: 'ai-interviewer-2ce7d.firebasestorage.app',
    iosBundleId: 'com.example.aiInterviewer',
  );
}
