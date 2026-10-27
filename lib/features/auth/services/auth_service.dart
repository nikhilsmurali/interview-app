import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  User? get user => _user;

  AuthService() {
    _initAuth();
  }

  void _initAuth() {
    try {
      if (Firebase.apps.isNotEmpty) {
        _auth = FirebaseAuth.instance;
        _auth!.authStateChanges().listen((User? user) {
          _user = user;
          notifyListeners();
        });
      } else {
        debugPrint("AuthService: Firebase not yet initialized");
      }
    } catch (e) {
      debugPrint("AuthService initialization error: $e");
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (_auth == null) {
        if (Firebase.apps.isNotEmpty) {
          _auth = FirebaseAuth.instance;
        } else {
          debugPrint("Google Sign In Error: Firebase is not initialized");
          return null;
        }
      }

      if (kIsWeb) {
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        return await _auth!.signInWithPopup(authProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // User cancelled

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth!.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint("Google Sign In Error: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth?.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint("Sign Out Error: $e");
    }
  }
}
