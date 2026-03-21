import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // instance of auth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send a magic link to user's email
  Future<void> sendMagicLink(String email) async {
    final ActionCodeSettings acs = ActionCodeSettings(
      url: 'www.campus-link.com',
      handleCodeInApp: true,
      iOSBundleId: 'com.example.ios',
      androidPackageName: 'com.example.android',
      androidInstallApp: true,
      androidMinimumVersion: '21',
    );

    try {
      await _auth.sendSignInLinkToEmail(email: email, actionCodeSettings: acs);
      if (kDebugMode) {
        print('Magic link sent to $email');
      }
    } catch (e) {
      if (kDebugMode) print("Error sending magic link : $e");
    }
  }

  /// Complete sign in when user clicks the link
  Future<User?> signInWithLink(String email, String emailLink) async {
    try {
      if (_auth.isSignInWithEmailLink(emailLink)) {
        UserCredential userCredential = await _auth.signInWithEmailLink(
          email: email,
          emailLink: emailLink,
        );
        return userCredential.user;
      } else {
        if (kDebugMode) print("Not a valid magic link");
        return null;
      }
    } catch (e) {
      if (kDebugMode) print("Error signing in: $e");
      return null;
    }
  }
}
