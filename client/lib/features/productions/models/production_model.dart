import 'package:cloud_firestore/cloud_firestore.dart';

class ProductionStatus {
  static const String planning = 'Planning';
  static const String inRehearsal = 'In Rehearsal';
  static const String completed = 'Completed';

  static const List<String> all = [
    planning,
    inRehearsal,
    completed,
  ];
}

class Production {
  final String id;
  final String title;
  final String description;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final String? director;
  final DateTime? createdAt;

  const Production({
    required this.id,
    required this.title,
    this.description = '',
    this.startDate,
    this.endDate,
    this.status = ProductionStatus.planning,
    this.director,
    this.createdAt,
  });

  Production copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? director,
    DateTime? createdAt,
  }) {
    return Production(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      director: director ?? this.director,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'status': status,
      'director': director?.trim(),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory Production.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Production(
      id: id,
      title: map['title'] as String? ?? 'Untitled Production',
      description: map['description'] as String? ?? '',
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      status: map['status'] as String? ?? ProductionStatus.planning,
      director: map['director'] as String?,
      createdAt: parseDate(map['createdAt']),
    );
  }

  factory Production.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Production.fromMap(data, doc.id);
  }

  /// Formats date to a readable string like 'Oct 15, 2026' or 'TBD'
  static String formatDate(DateTime? date) {
    if (date == null) return 'TBD';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthName = months[date.month - 1];
    return '$monthName ${date.day}, ${date.year}';
  }

  /// Returns date range as string e.g. 'Oct 15, 2026 – Dec 20, 2026'
  String get dateRangeFormatted {
    if (startDate == null && endDate == null) return 'Dates to be announced';
    if (startDate != null && endDate != null) {
      return '${formatDate(startDate)} – ${formatDate(endDate)}';
    }
    if (startDate != null) {
      return 'Starts ${formatDate(startDate)}';
    }
    return 'Ends ${formatDate(endDate)}';
  }
}
