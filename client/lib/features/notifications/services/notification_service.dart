import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseMessaging? messaging;

  NotificationService({FirebaseFirestore? firestore, this.messaging})
    : _customFirestore = firestore;

  FirebaseMessaging? get _messaging => messaging;

  FirebaseFirestore get firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  /// Registers the FCM device push token if supported on this device/platform.
  /// Safely catches unsupported platforms (e.g. Windows desktop, Web without VAPID key).
  Future<String?> registerFCMToken(String userId) async {
    if (userId.trim().isEmpty) return null;
    try {
      final msg = _messaging ?? FirebaseMessaging.instance;
      final settings = await msg.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await msg.getToken();
        if (token != null && token.isNotEmpty) {
          // Store token under user's token collection
          await firestore.collection('user_tokens').doc(userId.trim()).set({
            'userId': userId.trim(),
            'fcmToken': token,
            'updatedAt': FieldValue.serverTimestamp(),
            'platform': defaultTargetPlatform.name,
          }, SetOptions(merge: true));

          return token;
        }
      }
    } catch (e) {
      // Platform unsupported or missing configuration is handled gracefully
      debugPrint('FCM Token registration skipped or unsupported: $e');
    }
    return null;
  }

  /// Streams notifications for a specific user (and global 'all' announcements).
  Stream<List<AppNotification>> streamNotifications({required String userId}) {
    final uid = userId.trim();
    if (uid.isEmpty || uid == 'guest') return Stream.value([]);
    try {
      return firestore
          .collection('notifications')
          .where('recipientUid', whereIn: [uid, 'all'])
          .snapshots()
          .map((snapshot) {
            final list = snapshot.docs
                .map(
                  (doc) =>
                      AppNotification.fromMap(doc.data(), doc.id, userId: uid),
                )
                .toList();

            list.sort((a, b) {
              final aTime =
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime =
                  b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime); // Latest first
            });

            return list;
          });
    } catch (_) {
      return Stream.value([]);
    }
  }

  /// Creates a new notification document.
  Future<AppNotification> createNotification(
    AppNotification notification,
  ) async {
    final docRef = await firestore
        .collection('notifications')
        .add(notification.toMap());
    return notification.copyWith(id: docRef.id);
  }

  /// Marks a specific notification as read.
  Future<void> markAsRead(
    String notificationId, {
    required String userId,
  }) async {
    final uid = userId.trim();
    if (notificationId.trim().isEmpty || uid.isEmpty || uid == 'guest') return;
    final notification = firestore
        .collection('notifications')
        .doc(notificationId.trim());
    final snapshot = await notification.get();
    if (!snapshot.exists) return;
    final recipientUid = snapshot.data()?['recipientUid'] as String? ?? 'all';
    if (recipientUid == 'all') {
      await notification.update({
        'readBy': FieldValue.arrayUnion([uid]),
      });
    } else if (recipientUid == uid) {
      await notification.update({'read': true});
    }
  }

  /// Marks all unread notifications for a user as read.
  Future<void> markAllAsRead(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty || uid == 'guest') return;
    final snapshot = await firestore
        .collection('notifications')
        .where('recipientUid', whereIn: [uid, 'all'])
        .get();
    final batch = firestore.batch();
    bool hasUpdates = false;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final recipient = data['recipientUid'] as String? ?? 'all';
      final read = data['read'] as bool? ?? false;
      if (recipient == 'all') {
        final readBy = data['readBy'] as List<dynamic>? ?? const [];
        if (!readBy.contains(uid)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([uid]),
          });
          hasUpdates = true;
        }
      } else if (!read && recipient == uid) {
        batch.update(doc.reference, {'read': true});
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  /// Helper to notify schedule changes for rehearsals.
  Future<void> notifyRehearsalChange({
    required String rehearsalTitle,
    required String changeDetails,
    String? productionId,
    String? rehearsalId,
  }) async {
    await createNotification(
      AppNotification(
        id: '',
        recipientUid: 'all',
        title: 'Rehearsal Updated: $rehearsalTitle',
        message: changeDetails,
        type: NotificationType.rehearsalChange,
        relatedId: rehearsalId,
      ),
    );
  }

  /// Helper to notify schedule changes for auditions.
  Future<void> notifyAuditionChange({
    required String auditionTitle,
    required String changeDetails,
    String? productionId,
    String? auditionId,
  }) async {
    await createNotification(
      AppNotification(
        id: '',
        recipientUid: 'all',
        title: 'Audition Notice: $auditionTitle',
        message: changeDetails,
        type: NotificationType.auditionChange,
        relatedId: auditionId,
      ),
    );
  }
}
