import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  bool? _isAdminCached;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<bool> isAdmin() async {
    final user = currentUser;
    if (user == null) return false;

    // Return cached value if available
    if (_isAdminCached != null) return _isAdminCached!;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        _isAdminCached = data?['role'] == 'admin';
        return _isAdminCached!;
      }
      
      // If no doc exists, check if email is in a hardcoded admin list for initial setup
      final adminEmails = ['saijayanth567@gmail.com', 'admin@shareindia.org'];
      if (adminEmails.contains(user.email)) {
        // Create the user doc with admin role if it doesn't exist
        await _db.collection('users').doc(user.uid).set({
          'email': user.email,
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
        });
        _isAdminCached = true;
        return true;
      }
    } catch (e) {
      debugPrint('Error checking admin role: $e');
    }
    return false;
  }

  Future<void> signOut() async {
    _isAdminCached = null; // Clear cache on sign out
    await _auth.signOut();
  }
}
