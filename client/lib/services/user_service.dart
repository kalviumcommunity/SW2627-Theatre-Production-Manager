import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore? _firestore;

  UserService({this._firestore});

  FirebaseFirestore? get firestore {
    try {
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Creates or updates a user profile document in Firestore at `users/{uid}`.
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String role,
  }) async {
    final fs = firestore;
    if (fs == null) return;
    await fs.collection('users').doc(uid).set({
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'role': role.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches a user profile document from `users/{uid}`.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final fs = firestore;
    if (fs == null) return null;
    final docSnapshot = await fs.collection('users').doc(uid).get();
    return docSnapshot.data();
  }

  /// Streams a user profile document from `users/{uid}`.
  Stream<Map<String, dynamic>?> streamUserProfile(String uid) {
    final fs = firestore;
    if (fs == null) return const Stream.empty();
    return fs
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }
}
