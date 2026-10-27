import 'package:cloud_firestore/cloud_firestore.dart';

class AuditionStatus {
  static const String scheduled = 'Scheduled';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';

  static const List<String> all = [scheduled, completed, cancelled];
}

class Audition {
  final String id;
  final String productionId;
  final String title;
  final String venue;
  final String? venueId;
  final DateTime startTime;
  final DateTime endTime;
  final String description;
  final String requirements;
  final String status;
  final String creatorUid;
  final String? cancellationReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Audition({
    required this.id,
    required this.productionId,
    required this.title,
    required this.venue,
    this.venueId,
    required this.startTime,
    required this.endTime,
    required this.creatorUid,
    this.description = '',
    this.requirements = '',
    this.status = AuditionStatus.scheduled,
    this.cancellationReason,
    this.createdAt,
    this.updatedAt,
  });

  /// Returns true if end time is strictly after start time.
  bool get isValidTimeRange => endTime.isAfter(startTime);

  /// Duration of the audition session.
  Duration get duration => endTime.difference(startTime);

  bool get isScheduled => status == AuditionStatus.scheduled;
  bool get isCompleted => status == AuditionStatus.completed;
  bool get isCancelled => status == AuditionStatus.cancelled;

  Audition copyWith({
    String? id,
    String? productionId,
    String? title,
    String? venue,
    String? venueId,
    DateTime? startTime,
    DateTime? endTime,
    String? description,
    String? requirements,
    String? status,
    String? creatorUid,
    String? cancellationReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Audition(
      id: id ?? this.id,
      productionId: productionId ?? this.productionId,
      title: title ?? this.title,
      venue: venue ?? this.venue,
      venueId: venueId ?? this.venueId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      status: status ?? this.status,
      creatorUid: creatorUid ?? this.creatorUid,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productionId': productionId.trim(),
      'title': title.trim(),
      'venue': venue.trim(),
      if (venueId != null && venueId!.trim().isNotEmpty)
        'venueId': venueId!.trim(),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'description': description.trim(),
      'requirements': requirements.trim(),
      'status': status,
      'creatorUid': creatorUid.trim(),
      if (cancellationReason != null)
        'cancellationReason': cancellationReason!.trim(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory Audition.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final parsedStart =
        parseDate(map['startTime']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final parsedEnd =
        parseDate(map['endTime']) ?? parsedStart.add(const Duration(hours: 2));

    return Audition(
      id: id,
      productionId: map['productionId'] as String? ?? '',
      title: map['title'] as String? ?? 'Audition Session',
      venue: map['venue'] as String? ?? '',
      venueId: map['venueId'] as String?,
      startTime: parsedStart,
      endTime: parsedEnd,
      description: map['description'] as String? ?? '',
      requirements: map['requirements'] as String? ?? '',
      status: map['status'] as String? ?? AuditionStatus.scheduled,
      creatorUid:
          map['creatorUid'] as String? ?? map['createdBy'] as String? ?? '',
      cancellationReason: map['cancellationReason'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  factory Audition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Audition.fromMap(data, doc.id);
  }

  static String formatDate(DateTime? date) {
    if (date == null) return 'TBD';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthName = months[date.month - 1];
    return '$monthName ${date.day}, ${date.year}';
  }

  static String formatTime(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  String get timeWindowFormatted =>
      '${formatTime(startTime)} – ${formatTime(endTime)}';
}
