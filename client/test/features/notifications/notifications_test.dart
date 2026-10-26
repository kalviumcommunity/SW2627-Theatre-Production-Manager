import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/features/notifications/models/notification_model.dart';
import 'package:client/features/notifications/screens/notifications_screen.dart';
import 'package:client/features/notifications/services/notification_service.dart';
import 'package:client/features/notifications/widgets/notification_tile.dart';

class _FakeNotificationService extends NotificationService {
  final List<AppNotification> notifications;
  String? lastReadId;

  _FakeNotificationService({List<AppNotification>? initial})
    : notifications = initial ?? [];

  @override
  Stream<List<AppNotification>> streamNotifications({required String userId}) {
    return Stream.value(notifications);
  }

  @override
  Future<void> markAsRead(String id, {required String userId}) async {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      notifications[idx] = notifications[idx].copyWith(read: true);
    }
    lastReadId = id;
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    for (int i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(read: true);
    }
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(home: child);
}

void main() {
  group('Notification Model Tests', () {
    test('serializes to and from Map correctly', () {
      final now = DateTime(2026, 11, 15, 10, 0);
      final notif = AppNotification(
        id: 'n1',
        recipientUid: 'user-1',
        title: 'Rehearsal Time Changed',
        message: 'Moved from 2pm to 3pm',
        type: NotificationType.rehearsalChange,
        relatedId: 'reh-123',
        read: false,
        createdAt: now,
      );

      final map = notif.toMap();
      expect(map['recipientUid'], 'user-1');
      expect(map['title'], 'Rehearsal Time Changed');
      expect(map['type'], NotificationType.rehearsalChange);
      expect(map['relatedId'], 'reh-123');
      expect(map['read'], isFalse);

      final reconstructed = AppNotification.fromMap({
        'recipientUid': 'user-1',
        'title': 'Rehearsal Time Changed',
        'message': 'Moved from 2pm to 3pm',
        'type': NotificationType.rehearsalChange,
        'relatedId': 'reh-123',
        'read': true,
        'createdAt': now,
      }, 'n1');

      expect(reconstructed.id, 'n1');
      expect(reconstructed.read, isTrue);

      final globalNotification = AppNotification.fromMap(
        {
          'recipientUid': 'all',
          'title': 'Announcement',
          'message': 'Company call',
          'read': false,
          'readBy': ['user-1'],
        },
        'n2',
        userId: 'user-1',
      );
      expect(globalNotification.read, isTrue);
      expect(
        AppNotification.fromMap(
          {
            'recipientUid': 'all',
            'title': 'Announcement',
            'message': 'Company call',
            'read': false,
            'readBy': ['user-1'],
          },
          'n2',
          userId: 'user-2',
        ).read,
        isFalse,
      );
    });
  });

  group('NotificationTile Tests', () {
    testWidgets('renders title, message, and responds to tap', (tester) async {
      bool tapped = false;
      final notif = AppNotification(
        id: 'n1',
        recipientUid: 'all',
        title: 'Casting Announcement',
        message: 'Call-backs posted on bulletin',
        type: NotificationType.announcement,
        read: false,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrap(
          NotificationTile(notification: notif, onTap: () => tapped = true),
        ),
      );

      expect(find.text('Casting Announcement'), findsOneWidget);
      expect(find.text('Call-backs posted on bulletin'), findsOneWidget);

      await tester.tap(find.byType(NotificationTile));
      expect(tapped, isTrue);
    });
  });

  group('NotificationsScreen Tests', () {
    testWidgets('renders empty state when no notifications exist', (
      tester,
    ) async {
      final fake = _FakeNotificationService(initial: []);

      await tester.pumpWidget(
        _wrap(NotificationsScreen(notificationService: fake)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No notifications yet'), findsOneWidget);
    });

    testWidgets('filters unread notifications and marks all as read', (
      tester,
    ) async {
      final fake = _FakeNotificationService(
        initial: [
          AppNotification(
            id: 'n1',
            recipientUid: 'all',
            title: 'Schedule Change',
            message: 'Scene 4 moved',
            read: false,
            createdAt: DateTime.now(),
          ),
          AppNotification(
            id: 'n2',
            recipientUid: 'all',
            title: 'Venue Booked',
            message: 'Main hall confirmed',
            read: true,
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(NotificationsScreen(notificationService: fake)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Schedule Change'), findsOneWidget);
      expect(find.text('Venue Booked'), findsOneWidget);

      // Filter Unread
      await tester.tap(find.text('Unread (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Schedule Change'), findsOneWidget);
      expect(find.text('Venue Booked'), findsNothing);

      // Tap Mark all as read
      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();

      expect(fake.notifications.every((n) => n.read), isTrue);
    });
  });
}
