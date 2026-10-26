import 'package:flutter/material.dart';
import 'package:client/services/auth_service.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends StatefulWidget {
  final bool showAppBar;
  final NotificationService? notificationService;
  final AuthService? authService;
  final String? currentUserId;

  const NotificationsScreen({
    super.key,
    this.showAppBar = true,
    this.notificationService,
    this.authService,
    this.currentUserId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationService _notificationService;
  late final AuthService _authService;

  String? _userId;
  String _filter = 'All'; // 'All' or 'Unread'

  @override
  void initState() {
    super.initState();
    _notificationService = widget.notificationService ?? NotificationService();
    _authService = widget.authService ?? AuthService();

    if (widget.currentUserId != null) {
      _userId = widget.currentUserId;
    } else {
      try {
        final user = _authService.currentUser;
        _userId = user?.uid ?? 'guest';

        if (user != null) {
          _notificationService.registerFCMToken(user.uid);
        }
      } catch (_) {
        _userId = 'guest';
      }
    }
  }

  void _markAsRead(AppNotification notification) {
    if (!notification.read) {
      _notificationService.markAsRead(notification.id, userId: _userId ?? '');
    }
  }

  void _markAllAsRead() {
    if (_userId != null) {
      _notificationService.markAllAsRead(_userId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = _userId ?? 'guest';

    final content = StreamBuilder<List<AppNotification>>(
      stream: _notificationService.streamNotifications(userId: userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text('Error loading notifications: ${snapshot.error}'),
              ],
            ),
          );
        }

        final all = snapshot.data ?? [];
        final filtered = all.where((n) {
          if (_filter == 'Unread') return !n.read;
          return true;
        }).toList();

        final unreadCount = all.where((n) => !n.read).length;

        return Column(
          children: [
            // Top action bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  FilterChip(
                    label: Text('All (${all.length})'),
                    selected: _filter == 'All',
                    selectedColor: const Color(0xFF8B1E3F)
                        .withValues(alpha: 0.15),
                    checkmarkColor: const Color(0xFF8B1E3F),
                    labelStyle: TextStyle(
                      color: _filter == 'All'
                          ? const Color(0xFF8B1E3F)
                          : theme.colorScheme.onSurface,
                      fontWeight: _filter == 'All'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _filter = 'All');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('Unread ($unreadCount)'),
                    selected: _filter == 'Unread',
                    selectedColor: const Color(0xFF8B1E3F)
                        .withValues(alpha: 0.15),
                    checkmarkColor: const Color(0xFF8B1E3F),
                    labelStyle: TextStyle(
                      color: _filter == 'Unread'
                          ? const Color(0xFF8B1E3F)
                          : theme.colorScheme.onSurface,
                      fontWeight: _filter == 'Unread'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _filter = 'Unread');
                    },
                  ),
                  const Spacer(),
                  if (unreadCount > 0)
                    TextButton.icon(
                      onPressed: _markAllAsRead,
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Mark all as read'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8B1E3F),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Notification list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none_outlined,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filter == 'Unread'
                                ? 'No unread notifications'
                                : 'No notifications yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Schedule changes, call times, and casting updates will appear here.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notification = filtered[index];
                        return NotificationTile(
                          notification: notification,
                          onTap: () => _markAsRead(notification),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Notifications',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: content,
      );
    }

    return content;
  }
}
