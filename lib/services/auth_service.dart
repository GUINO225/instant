import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signInWithGoogleWeb() async {
    final provider = GoogleAuthProvider();
    final credential = await _auth.signInWithPopup(provider);
    final user = credential.user;
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();
    final existing = await ref.get();
    final existingData = existing.data();

    await ref.set({
      'uid': user.uid,
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'phone': existingData?['phone'] ?? user.phoneNumber ?? '',
      'role': existingData?['role'] ?? 'client',
      'createdAt': existingData?['createdAt'] ?? now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> signOut() => _auth.signOut();
}
