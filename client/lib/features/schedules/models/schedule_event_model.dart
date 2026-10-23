enum ScheduleEventType {
  rehearsal,
  audition,
}

class ScheduleEvent {
  final String id;
  final String title;
  final String productionId;
  final String productionTitle;
  final String venue;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final ScheduleEventType type;
  final String notes;
  final dynamic originalObject;

  const ScheduleEvent({
    required this.id,
    required this.title,
    required this.productionId,
    required this.productionTitle,
    required this.venue,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.type,
    this.notes = '',
    this.originalObject,
  });

  bool get isRehearsal => type == ScheduleEventType.rehearsal;
  bool get isAudition => type == ScheduleEventType.audition;

  String get typeLabel => isRehearsal ? 'Rehearsal' : 'Audition';

  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  bool get isUpcoming => endTime.isAfter(DateTime.now());

  String get formattedTimeRange {
    final start =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final end =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[startTime.month - 1]} ${startTime.day}, ${startTime.year}';
  }
}
