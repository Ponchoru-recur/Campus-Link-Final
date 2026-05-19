import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Streams the current user's Firestore document and exposes role, isApproved, isRevoked.
///
/// Call [startListening] when the user authenticates, [stopListening] on logout.
class UserService extends ChangeNotifier {
  StreamSubscription<DocumentSnapshot>? _subscription;

  String role = 'student';
  bool isApproved = false;
  bool isRevoked = false;

  void startListening(String uid) {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data != null) {
        role = data['role'] ?? 'student';
        isApproved = data['isApproved'] ?? false;
        isRevoked = data['isRevoked'] ?? false;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('UserService stream error: $e');
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    role = 'student';
    isApproved = false;
    isRevoked = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}