import 'package:cloud_firestore/cloud_firestore.dart';

class CastAssignmentStatus {
  static const String assigned = 'Assigned';
  static const String confirmed = 'Confirmed';
  static const String understudy = 'Understudy';
  static const String invited = 'Invited';

  static const List<String> all = [assigned, confirmed, understudy, invited];
}

class CastAssignment {
  final String id;
  final String productionId;
  final String userId;
  final String characterRole;
  final String actorName;
  final String actorEmail;
  final String status;
  final String notes;
  final DateTime? assignedAt;
  final String assignedBy;

  const CastAssignment({
    required this.id,
    required this.productionId,
    required this.userId,
    required this.characterRole,
    required this.actorName,
    this.actorEmail = '',
    this.status = CastAssignmentStatus.assigned,
    this.notes = '',
    this.assignedAt,
    this.assignedBy = '',
  });

  CastAssignment copyWith({
    String? id,
    String? productionId,
    String? userId,
    String? characterRole,
    String? actorName,
    String? actorEmail,
    String? status,
    String? notes,
    DateTime? assignedAt,
    String? assignedBy,
  }) {
    return CastAssignment(
      id: id ?? this.id,
      productionId: productionId ?? this.productionId,
      userId: userId ?? this.userId,
      characterRole: characterRole ?? this.characterRole,
      actorName: actorName ?? this.actorName,
      actorEmail: actorEmail ?? this.actorEmail,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      assignedAt: assignedAt ?? this.assignedAt,
      assignedBy: assignedBy ?? this.assignedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productionId': productionId.trim(),
      'userId': userId.trim(),
      'characterRole': characterRole.trim(),
      'actorName': actorName.trim(),
      'actorEmail': actorEmail.trim(),
      'status': status,
      'notes': notes.trim(),
      'assignedAt': assignedAt != null
          ? Timestamp.fromDate(assignedAt!)
          : FieldValue.serverTimestamp(),
      'assignedBy': assignedBy.trim(),
    };
  }

  factory CastAssignment.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return CastAssignment(
      id: id,
      productionId: (map['productionId'] as String? ?? '').trim(),
      userId: (map['userId'] as String? ?? '').trim(),
      characterRole: (map['characterRole'] as String? ?? '').trim(),
      actorName: (map['actorName'] as String? ?? '').trim(),
      actorEmail: (map['actorEmail'] as String? ?? '').trim(),
      status: (map['status'] as String? ?? CastAssignmentStatus.assigned).trim(),
      notes: (map['notes'] as String? ?? '').trim(),
      assignedAt: parseDate(map['assignedAt']),
      assignedBy: (map['assignedBy'] as String? ?? '').trim(),
    );
  }
}

class ProductionRoleSlot {
  final String characterRole;
  final CastAssignment? assignment;

  const ProductionRoleSlot({
    required this.characterRole,
    this.assignment,
  });

  bool get isAssigned => assignment != null;
  bool get isVacant => assignment == null;
}
