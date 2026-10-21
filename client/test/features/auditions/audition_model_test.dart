import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/auditions/models/audition_model.dart';

void main() {
  group('Audition Model Tests', () {
    final start = DateTime(2026, 11, 5, 10, 0);
    final end = DateTime(2026, 11, 5, 14, 0);

    test('serializes to and from Map correctly', () {
      final audition = Audition(
        id: 'aud-1',
        productionId: 'prod-1',
        title: 'Lead Roles Audition',
        venue: 'Studio A',
        startTime: start,
        endTime: end,
        description: 'Open call for leads',
        requirements: 'Prepare 16 bars',
        status: AuditionStatus.scheduled,
        creatorUid: 'dir-1',
        createdAt: DateTime(2026, 10, 20),
        updatedAt: DateTime(2026, 10, 21),
      );

      final map = audition.toMap();

      expect(map['productionId'], 'prod-1');
      expect(map['title'], 'Lead Roles Audition');
      expect(map['venue'], 'Studio A');
      expect(map['startTime'], isA<Timestamp>());
      expect(map['endTime'], isA<Timestamp>());
      expect(map['description'], 'Open call for leads');
      expect(map['requirements'], 'Prepare 16 bars');
      expect(map['status'], 'Scheduled');
      expect(map['creatorUid'], 'dir-1');

      final fromMap = Audition.fromMap(map, 'aud-1');
      expect(fromMap.id, 'aud-1');
      expect(fromMap.productionId, 'prod-1');
      expect(fromMap.title, 'Lead Roles Audition');
      expect(fromMap.venue, 'Studio A');
      expect(fromMap.startTime, start);
      expect(fromMap.endTime, end);
      expect(fromMap.description, 'Open call for leads');
      expect(fromMap.requirements, 'Prepare 16 bars');
      expect(fromMap.status, AuditionStatus.scheduled);
      expect(fromMap.creatorUid, 'dir-1');
    });

    test('validates time range and duration', () {
      final valid = Audition(
        id: '1',
        productionId: 'prod-1',
        title: 'Call',
        venue: 'Hall',
        startTime: start,
        endTime: end,
        creatorUid: 'dir-1',
      );
      expect(valid.isValidTimeRange, isTrue);
      expect(valid.duration, const Duration(hours: 4));

      final invalid = valid.copyWith(endTime: start);
      expect(invalid.isValidTimeRange, isFalse);

      final reversed = valid.copyWith(
        endTime: start.subtract(const Duration(hours: 1)),
      );
      expect(reversed.isValidTimeRange, isFalse);
    });

    test('status helper flags', () {
      final scheduled = Audition(
        id: '1',
        productionId: 'p',
        title: 'T',
        venue: 'V',
        startTime: start,
        endTime: end,
        creatorUid: 'u',
        status: AuditionStatus.scheduled,
      );
      expect(scheduled.isScheduled, isTrue);
      expect(scheduled.isCompleted, isFalse);
      expect(scheduled.isCancelled, isFalse);

      final completed = scheduled.copyWith(status: AuditionStatus.completed);
      expect(completed.isScheduled, isFalse);
      expect(completed.isCompleted, isTrue);
      expect(completed.isCancelled, isFalse);

      final cancelled = scheduled.copyWith(
        status: AuditionStatus.cancelled,
        cancellationReason: 'Production postponed',
      );
      expect(cancelled.isScheduled, isFalse);
      expect(cancelled.isCompleted, isFalse);
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.cancellationReason, 'Production postponed');
    });

    test('copyWith updates fields correctly', () {
      final a = Audition(
        id: '1',
        productionId: 'p1',
        title: 'Old Title',
        venue: 'Old Venue',
        startTime: start,
        endTime: end,
        creatorUid: 'u1',
      );

      final updated = a.copyWith(
        title: 'New Title',
        venue: 'New Venue',
        requirements: 'New Req',
      );

      expect(updated.id, '1');
      expect(updated.title, 'New Title');
      expect(updated.venue, 'New Venue');
      expect(updated.requirements, 'New Req');
      expect(updated.productionId, 'p1');
    });

    test('formatDate and formatTime produce readable output', () {
      final dt = DateTime(2026, 11, 5, 14, 30);
      expect(Audition.formatDate(dt), 'Nov 5, 2026');
      expect(Audition.formatTime(dt), '2:30 PM');
      expect(Audition.formatDate(null), 'TBD');
      expect(Audition.formatTime(null), '');
    });
  });
}
