import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationType {
  static const String rehearsalChange = 'rehearsal_change';
  static const String auditionChange = 'audition_change';
  static const String roleAssignment = 'role_assignment';
  static const String announcement = 'announcement';
  static const String general = 'general';
}

class AppNotification {
  final String id;
  final String recipientUid; // 'all' or specific user UID
  final String title;
  final String message;
  final String type;
  final String? relatedId;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.recipientUid,
    required this.title,
    required this.message,
    this.type = NotificationType.general,
    this.relatedId,
    this.read = false,
    this.createdAt,
  });

  AppNotification copyWith({
    String? id,
    String? recipientUid,
    String? title,
    String? message,
    String? type,
    String? relatedId,
    bool? read,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      recipientUid: recipientUid ?? this.recipientUid,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientUid': recipientUid.trim(),
      'title': title.trim(),
      'message': message.trim(),
      'type': type,
      if (relatedId != null) 'relatedId': relatedId!.trim(),
      'read': read,
      if (recipientUid.trim() == 'all') 'readBy': <String>[],
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory AppNotification.fromMap(
    Map<String, dynamic> map,
    String id, {
    String? userId,
  }) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final recipientUid = (map['recipientUid'] as String? ?? 'all').trim();
    final readBy = map['readBy'] as List<dynamic>? ?? const [];
    return AppNotification(
      id: id,
      recipientUid: recipientUid,
      title: (map['title'] as String? ?? '').trim(),
      message: (map['message'] as String? ?? '').trim(),
      type: (map['type'] as String? ?? NotificationType.general).trim(),
      relatedId: map['relatedId'] as String?,
      read: recipientUid == 'all'
          ? userId != null && readBy.contains(userId)
          : map['read'] as bool? ?? false,
      createdAt: parseDate(map['createdAt']),
    );
  }
}
