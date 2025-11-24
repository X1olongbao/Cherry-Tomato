import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/app_notification.dart';

/// Simple in-app notification hub.
/// Uses ValueNotifier for UI updates; persistence can be added later.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final ValueNotifier<List<AppNotification>> notifications =
      ValueNotifier<List<AppNotification>>([]);

  final _uuid = const Uuid();

  void add(AppNotification n) {
    final list = List<AppNotification>.from(notifications.value);
    list.insert(0, n); // newest first
    notifications.value = list;
  }

  /// Convenience: adds a "First Pomodoro" congrats notification.
  void addFirstPomodoroCongrats() {
    add(AppNotification(
      id: _uuid.v4(),
      title: 'Notification',
      message: 'Congratulations on Completing Your First Pomodoro!',
      createdAt: DateTime.now(),
    ));
  }

  /// Marks all notifications as read (non-persistent).
  void markAllRead() {
    notifications.value = notifications.value
        .map((n) => n.copyWith(read: true))
        .toList(growable: false);
  }
}