import 'package:cloud_firestore/cloud_firestore.dart';

class Rehearsal {
  final String id;
  final String productionId;
  final String title;
  final String venueId;
  final String venueName;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? createdAt;
  final String creatorUid;
  final String notes;

  const Rehearsal({
    required this.id,
    required this.productionId,
    required this.venueId,
    required this.startTime,
    required this.endTime,
    required this.creatorUid,
    this.title = 'Rehearsal',
    this.venueName = '',
    this.createdAt,
    this.notes = '',
  });

  /// Canonical venue label, preferring venueName if provided, falling back to venueId.
  String get venue => venueName.isNotEmpty ? venueName : venueId;

  /// Returns true if the end time is strictly after the start time.
  bool get isValidTimeRange => endTime.isAfter(startTime);

  /// Duration of the rehearsal.
  Duration get duration => endTime.difference(startTime);

  Rehearsal copyWith({
    String? id,
    String? productionId,
    String? title,
    String? venueId,
    String? venueName,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? createdAt,
    String? creatorUid,
    String? notes,
  }) {
    return Rehearsal(
      id: id ?? this.id,
      productionId: productionId ?? this.productionId,
      title: title ?? this.title,
      venueId: venueId ?? this.venueId,
      venueName: venueName ?? this.venueName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
      creatorUid: creatorUid ?? this.creatorUid,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productionId': productionId.trim(),
      'title': title.trim(),
      'venueId': venueId.trim(),
      'venueName': venueName.trim(),
      'venue': venue.trim(),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      // scheduledAt provides seamless compatibility with upcoming rehearsals dashboard card
      'scheduledAt': Timestamp.fromDate(startTime),
      'creatorUid': creatorUid.trim(),
      'notes': notes.trim(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory Rehearsal.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final parsedStart = parseDate(map['startTime']) ??
        parseDate(map['scheduledAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final parsedEnd = parseDate(map['endTime']) ??
        parsedStart.add(const Duration(hours: 2));

    final rawVenueId = map['venueId'] as String? ?? map['venue'] as String? ?? '';
    final rawVenueName = map['venueName'] as String? ?? map['venue'] as String? ?? '';

    return Rehearsal(
      id: id,
      productionId: map['productionId'] as String? ?? '',
      title: map['title'] as String? ?? 'Rehearsal',
      venueId: rawVenueId,
      venueName: rawVenueName,
      startTime: parsedStart,
      endTime: parsedEnd,
      creatorUid: map['creatorUid'] as String? ?? map['createdBy'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }

  factory Rehearsal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Rehearsal.fromMap(data, doc.id);
  }
}
