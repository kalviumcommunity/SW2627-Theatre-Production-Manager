import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore? _firestore;

  UserService({this._firestore});

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  /// Creates or updates a user profile document in Firestore at `users/{uid}`.
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String role,
  }) async {
    await firestore.collection('users').doc(uid).set({
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'role': role.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches a user profile document from `users/{uid}`.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final docSnapshot = await firestore.collection('users').doc(uid).get();
    return docSnapshot.data();
  }
}
