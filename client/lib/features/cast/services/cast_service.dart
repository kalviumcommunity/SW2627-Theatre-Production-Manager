import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cast_assignment_model.dart';

class CastValidationException implements Exception {
  final String message;
  const CastValidationException(this.message);

  @override
  String toString() => message;
}

class DuplicateRoleException implements Exception {
  final String roleName;
  final String productionId;
  const DuplicateRoleException(this.roleName, this.productionId);

  @override
  String toString() =>
      'Role "$roleName" is already assigned to an actor in this production.';
}

class EligibleUser {
  final String uid;
  final String name;
  final String email;

  const EligibleUser({
    required this.uid,
    required this.name,
    this.email = '',
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
      };

  factory EligibleUser.fromMap(Map<String, dynamic> map, String id) {
    return EligibleUser(
      uid: (map['uid'] as String? ?? id).trim(),
      name: (map['name'] as String? ?? '').trim(),
      email: (map['email'] as String? ?? '').trim(),
    );
  }
}

class CastService {
  final FirebaseFirestore? _customFirestore;

  CastService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  void validateAssignment(CastAssignment assignment) {
    if (assignment.productionId.trim().isEmpty) {
      throw const CastValidationException('Production ID is required.');
    }
    if (assignment.userId.trim().isEmpty) {
      throw const CastValidationException('User ID is required.');
    }
    if (assignment.characterRole.trim().isEmpty) {
      throw const CastValidationException('Character role is required.');
    }
    if (assignment.actorName.trim().isEmpty) {
      throw const CastValidationException('Actor name is required.');
    }
    if (!CastAssignmentStatus.all.contains(assignment.status)) {
      throw CastValidationException('Invalid status: ${assignment.status}');
    }
  }

  /// Checks if another assignment for the same production already has this character role.
  Future<CastAssignment?> findDuplicateRole(
    CastAssignment assignment, {
    String? excludeAssignmentId,
  }) async {
    final roleNorm = assignment.characterRole.trim().toLowerCase();
    final prodId = assignment.productionId.trim();

    final snapshot = await firestore
        .collection('cast_assignments')
        .where('productionId', isEqualTo: prodId)
        .get();

    for (final doc in snapshot.docs) {
      if (excludeAssignmentId != null && doc.id == excludeAssignmentId) {
        continue;
      }
      final existingRole =
          (doc.data()['characterRole'] as String? ?? '').trim().toLowerCase();
      if (existingRole == roleNorm) {
        return CastAssignment.fromMap(doc.data(), doc.id);
      }
    }
    return null;
  }

  /// Assigns an actor to a role in a production.
  Future<CastAssignment> assignCastMember(CastAssignment assignment) async {
    validateAssignment(assignment);

    final duplicate = await findDuplicateRole(assignment);
    if (duplicate != null) {
      throw DuplicateRoleException(
        assignment.characterRole,
        assignment.productionId,
      );
    }

    final docRef = await firestore
        .collection('cast_assignments')
        .add(assignment.toMap());

    // Also register user into eligible cast_members directory for discovery
    try {
      await firestore.collection('cast_members').doc(assignment.userId).set({
        'uid': assignment.userId,
        'name': assignment.actorName,
        'email': assignment.actorEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    return assignment.copyWith(id: docRef.id);
  }

  /// Updates an existing role assignment.
  Future<void> updateCastAssignment(CastAssignment assignment) async {
    if (assignment.id.trim().isEmpty) {
      throw ArgumentError('Assignment ID cannot be empty for update.');
    }
    validateAssignment(assignment);

    final duplicate = await findDuplicateRole(
      assignment,
      excludeAssignmentId: assignment.id,
    );
    if (duplicate != null) {
      throw DuplicateRoleException(
        assignment.characterRole,
        assignment.productionId,
      );
    }

    await firestore
        .collection('cast_assignments')
        .doc(assignment.id.trim())
        .update(assignment.toMap());
  }

  /// Removes a role assignment (e.g. unassigning or vacating the role).
  Future<void> removeCastAssignment(String assignmentId) async {
    if (assignmentId.trim().isEmpty) {
      throw ArgumentError('Assignment ID cannot be empty for deletion.');
    }
    await firestore
        .collection('cast_assignments')
        .doc(assignmentId.trim())
        .delete();
  }

  /// Streams cast assignments, optionally filtered by productionId.
  Stream<List<CastAssignment>> streamCastAssignments({String? productionId}) {
    try {
      Query<Map<String, dynamic>> query =
          firestore.collection('cast_assignments');

      if (productionId != null && productionId.trim().isNotEmpty) {
        query = query.where('productionId', isEqualTo: productionId.trim());
      }

      return query.snapshots().map((snapshot) => snapshot.docs
          .map((doc) => CastAssignment.fromMap(doc.data(), doc.id))
          .toList());
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Gets cast assignments as a one-shot Future.
  Future<List<CastAssignment>> getCastAssignments({String? productionId}) async {
    try {
      Query<Map<String, dynamic>> query =
          firestore.collection('cast_assignments');

      if (productionId != null && productionId.trim().isNotEmpty) {
        query = query.where('productionId', isEqualTo: productionId.trim());
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => CastAssignment.fromMap(doc.data(), doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Streams known eligible cast members.
  Stream<List<EligibleUser>> streamEligibleUsers() {
    try {
      return firestore.collection('cast_members').snapshots().map((snapshot) =>
          snapshot.docs
              .map((doc) => EligibleUser.fromMap(doc.data(), doc.id))
              .toList());
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Fetches known eligible cast members.
  Future<List<EligibleUser>> getEligibleUsers() async {
    try {
      final snapshot = await firestore.collection('cast_members').get();
      return snapshot.docs
          .map((doc) => EligibleUser.fromMap(doc.data(), doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Saves or refreshes an eligible user entry.
  Future<void> registerEligibleUser(EligibleUser user) async {
    await firestore.collection('cast_members').doc(user.uid).set(
          user.toMap(),
          SetOptions(merge: true),
        );
  }
}
