import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/schedules/models/schedule_event_model.dart';
import 'package:client/features/schedules/screens/master_schedule_screen.dart';
import 'package:client/features/schedules/services/schedule_service.dart';
import 'package:client/features/schedules/widgets/schedule_event_card.dart';

class _FakeScheduleService extends ScheduleService {
  final List<ScheduleEvent> events;

  _FakeScheduleService({List<ScheduleEvent>? initialEvents})
      : events = initialEvents ?? [];

  @override
  Future<List<ScheduleEvent>> getScheduleEvents({
    String? userId,
    bool isDirector = true,
    DateTime? dateFilter,
  }) async {
    var list = events;
    if (dateFilter != null) {
      list = list.where((e) =>
          e.startTime.year == dateFilter.year &&
          e.startTime.month == dateFilter.month &&
          e.startTime.day == dateFilter.day).toList();
    }
    return list;
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: child,
  );
}

void main() {
  group('ScheduleEvent Model Tests', () {
    test('formats time range and handles event types', () {
      final start = DateTime(2026, 11, 10, 9, 30);
      final end = DateTime(2026, 11, 10, 11, 45);

      final event = ScheduleEvent(
        id: 'e1',
        title: 'Act 1 Run-Through',
        productionId: 'p1',
        productionTitle: 'Macbeth',
        venue: 'Main Stage',
        startTime: start,
        endTime: end,
        status: 'Scheduled',
        type: ScheduleEventType.rehearsal,
      );

      expect(event.isRehearsal, isTrue);
      expect(event.isAudition, isFalse);
      expect(event.typeLabel, 'Rehearsal');
      expect(event.formattedTimeRange, '09:30 - 11:45');
      expect(event.formattedDate, 'Nov 10, 2026');
    });
  });

  group('ScheduleEventCard Tests', () {
    testWidgets('renders type badge, title, production, and time window', (tester) async {
      bool tapped = false;
      final start = DateTime(2026, 11, 10, 14, 0);
      final end = DateTime(2026, 11, 10, 16, 0);

      final event = ScheduleEvent(
        id: 'e2',
        title: 'Lead Roles Audition',
        productionId: 'p1',
        productionTitle: 'Hamlet',
        venue: 'Auditorium A',
        startTime: start,
        endTime: end,
        status: 'Scheduled',
        type: ScheduleEventType.audition,
      );

      await tester.pumpWidget(_wrap(
        ScheduleEventCard(
          event: event,
          onTap: () => tapped = true,
        ),
      ));

      expect(find.text('Audition'), findsOneWidget);
      expect(find.text('Lead Roles Audition'), findsOneWidget);
      expect(find.text('Hamlet'), findsOneWidget);
      expect(find.text('Auditorium A'), findsOneWidget);
      expect(find.text('14:00 - 16:00'), findsOneWidget);

      await tester.tap(find.byType(ScheduleEventCard));
      expect(tapped, isTrue);
    });
  });

  group('MasterScheduleScreen Tests', () {
    testWidgets('renders empty state when no events exist', (tester) async {
      final fakeService = _FakeScheduleService(initialEvents: []);

      await tester.pumpWidget(_wrap(
        MasterScheduleScreen(
          scheduleService: fakeService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No events scheduled yet.'), findsOneWidget);
    });

    testWidgets('renders events and filters by type chip', (tester) async {
      final fakeService = _FakeScheduleService(initialEvents: [
        ScheduleEvent(
          id: 'e1',
          title: 'Orchestra Rehearsal',
          productionId: 'p1',
          productionTitle: 'Phantom',
          venue: 'Pit',
          startTime: DateTime(2026, 11, 12, 10, 0),
          endTime: DateTime(2026, 11, 12, 12, 0),
          status: 'Scheduled',
          type: ScheduleEventType.rehearsal,
        ),
        ScheduleEvent(
          id: 'e2',
          title: 'Chorus Audition',
          productionId: 'p1',
          productionTitle: 'Phantom',
          venue: 'Studio A',
          startTime: DateTime(2026, 11, 12, 14, 0),
          endTime: DateTime(2026, 11, 12, 16, 0),
          status: 'Scheduled',
          type: ScheduleEventType.audition,
        ),
      ]);

      await tester.pumpWidget(_wrap(
        MasterScheduleScreen(
          scheduleService: fakeService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Orchestra Rehearsal'), findsOneWidget);
      expect(find.text('Chorus Audition'), findsOneWidget);

      // Tap Auditions filter chip
      await tester.tap(find.text('Auditions'));
      await tester.pumpAndSettle();

      expect(find.text('Chorus Audition'), findsOneWidget);
      expect(find.text('Orchestra Rehearsal'), findsNothing);
    });
  });
}
