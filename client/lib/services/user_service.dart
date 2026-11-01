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
    final batch = firestore.batch();
    batch.set(firestore.collection('users').doc(uid), {
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'role': role.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (role.trim() == 'Cast Member') {
      batch.set(firestore.collection('cast_members').doc(uid), {
        'uid': uid,
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Fetches a user profile document from `users/{uid}`.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final docSnapshot = await firestore.collection('users').doc(uid).get();
    return docSnapshot.data();
  }

  /// Streams a user profile document from `users/{uid}`.
  Stream<Map<String, dynamic>?> streamUserProfile(String uid) {
    return firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }
}
