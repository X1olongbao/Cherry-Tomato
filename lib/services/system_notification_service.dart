import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../utilities/logger.dart';

/// Service for managing system/local notifications
class SystemNotificationService {
  SystemNotificationService._();
  static final SystemNotificationService instance = SystemNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _notificationIdCounter = 1000;

  /// Initialize the notification service
  Future<void> init() async {
    if (kIsWeb || _initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    try {
      final offset = DateTime.now().timeZoneOffset;
      final hours = offset.inHours;
      String name;
      if (hours == 8) {
        name = 'Asia/Shanghai';
      } else if (hours == 0) {
        name = 'Etc/UTC';
      } else {
        final sign = hours >= 0 ? '-' : '+'; // Etc/GMT sign is inverted
        name = 'Etc/GMT$sign${hours.abs()}';
      }
      tz.setLocalLocation(tz.getLocation(name));
      Logger.i('Timezone set to $name');
    } catch (e) {
      Logger.w('Failed to set local timezone: $e');
      try {
        tz.setLocalLocation(tz.getLocation('Etc/UTC'));
        Logger.i('Timezone fallback to Etc/UTC');
      } catch (_) {}
    }

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    final android = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    _initialized = true;
    Logger.i('SystemNotificationService initialized');
  }

  String _resolveTimezoneName(String name) {
    return name;
  }

  Future<void> _createNotificationChannels() async {
    // Pomodoro channel
    const pomodoroChannel = AndroidNotificationChannel(
      'pomodoro_channel',
      'Pomodoro Sessions',
      description: 'Notifications for Pomodoro session start and end',
      importance: Importance.high,
      playSound: true,
    );

    // Task reminders channel
    const taskReminderChannel = AndroidNotificationChannel(
      'task_reminder_channel',
      'Task Reminders',
      description: 'Reminders for tasks that are due soon',
      importance: Importance.high,
      playSound: true,
    );

    // General reminders channel
    const generalReminderChannel = AndroidNotificationChannel(
      'general_reminder_channel',
      'General Reminders',
      description: 'General app reminders',
      importance: Importance.defaultImportance,
      playSound: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(pomodoroChannel);
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(taskReminderChannel);
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalReminderChannel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap if needed
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? false;
  }

  /// Set notifications enabled/disabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    Logger.i('Notifications enabled: $enabled');
    if (!enabled) {
      await cancelAllNotifications();
    }
  }

  /// Request notification-related permissions (Android)
  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    final android = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  // ========== Pomodoro Session Notifications ==========

  /// Show notification when Pomodoro session starts
  Future<void> notifyPomodoroStart({String? taskName}) async {
    if (kIsWeb || !_initialized) return;
    if (!await areNotificationsEnabled()) return;

    final title = 'Time to focus!';
    final body = taskName != null
        ? 'Pomodoro session started for "$taskName"'
        : 'Pomodoro session started.';

    const androidDetails = AndroidNotificationDetails(
      'pomodoro_channel',
      'Pomodoro Sessions',
      channelDescription: 'Notifications for Pomodoro session start and end',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationIdCounter++,
      title,
      body,
      details,
    );
  }

  /// Show notification when Pomodoro session ends
  Future<void> notifyPomodoroEnd({String? taskName}) async {
    if (kIsWeb || !_initialized) return;
    if (!await areNotificationsEnabled()) return;

    final title = 'Pomodoro completed!';
    final body = taskName != null
        ? 'Great work on "$taskName"! Time for a break.'
        : 'Great work! Time for a break.';

    const androidDetails = AndroidNotificationDetails(
      'pomodoro_channel',
      'Pomodoro Sessions',
      channelDescription: 'Notifications for Pomodoro session start and end',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationIdCounter++,
      title,
      body,
      details,
    );
  }

  /// Show notification when break starts
  Future<void> notifyBreakStart({required String breakType, required int durationMinutes}) async {
    if (kIsWeb || !_initialized) return;
    if (!await areNotificationsEnabled()) return;

    final title = 'Break time!';
    final body = '$breakType break started. Relax for $durationMinutes minutes.';

    const androidDetails = AndroidNotificationDetails(
      'pomodoro_channel',
      'Pomodoro Sessions',
      channelDescription: 'Notifications for Pomodoro session start and end',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _notificationIdCounter++,
      title,
      body,
      details,
    );
  }

  // ========== Task Reminder Notifications ==========

  /// Schedule a task reminder notification
  Future<int?> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    required DateTime reminderTime,
    required String reminderType, // 'due_soon', 'due_today', 'overdue', 'custom'
    String? customMessage,
  }) async {
    if (kIsWeb || !_initialized) return null;
    if (!await areNotificationsEnabled()) return null;

    final notificationId = _notificationIdCounter++;
    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

    String title;
    String body;

      switch (reminderType) {
        case 'due_soon':
          title = 'Task due soon';
          body = customMessage ?? 'Task "$taskTitle" is due soon.';
          break;
        case 'due_today':
          title = 'Task due today';
          body = customMessage ?? 'Task "$taskTitle" is due today.';
          break;
        case 'due_day_before':
          title = 'Task due tomorrow';
          body = customMessage ?? 'Task "$taskTitle" is due tomorrow.';
          break;
        case 'due_now':
          title = 'Task due now';
          body = customMessage ?? 'Task "$taskTitle" is due now.';
          break;
        case 'overdue':
          title = 'Task overdue';
          body = customMessage ?? 'Task "$taskTitle" is overdue.';
          break;
        default:
          title = 'Task reminder';
          body = customMessage ?? 'Reminder: "$taskTitle"';
      }

    const androidDetails = AndroidNotificationDetails(
      'task_reminder_channel',
      'Task Reminders',
      channelDescription: 'Reminders for tasks that are due soon',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    Logger.i('Scheduled task reminder $notificationId for "$taskTitle" at $scheduledDate');
    return notificationId;
  }

  Future<int> showTaskReminderNow({
    required String taskTitle,
    required String reminderType,
    String? customMessage,
  }) async {
    if (kIsWeb || !_initialized) return _notificationIdCounter++;
    if (!await areNotificationsEnabled()) return _notificationIdCounter++;

    final notificationId = _notificationIdCounter++;

    String title;
    String body;
    switch (reminderType) {
      case 'due_soon':
        title = 'Task due soon';
        body = customMessage ?? 'Task "$taskTitle" is due soon.';
        break;
      case 'due_today':
        title = 'Task due today';
        body = customMessage ?? 'Task "$taskTitle" is due today.';
        break;
      case 'due_day_before':
        title = 'Task due tomorrow';
        body = customMessage ?? 'Task "$taskTitle" is due tomorrow.';
        break;
      case 'overdue':
        title = 'Task overdue';
        body = customMessage ?? 'Task "$taskTitle" is overdue.';
        break;
      default:
        title = 'Task reminder';
        body = customMessage ?? 'Reminder: "$taskTitle"';
    }

    const androidDetails = AndroidNotificationDetails(
      'task_reminder_channel',
      'Task Reminders',
      channelDescription: 'Reminders for tasks that are due soon',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      notificationId,
      title,
      body,
      details,
    );

    Logger.i('Displayed immediate task reminder $notificationId for "$taskTitle"');
    return notificationId;
  }

  /// Cancel a scheduled task reminder
  Future<void> cancelTaskReminder(int notificationId) async {
    if (kIsWeb || !_initialized) return;
    await _notifications.cancel(notificationId);
    Logger.i('Cancelled task reminder $notificationId');
  }

  // ========== General App Reminders ==========

  /// Schedule a general app reminder (e.g., "Don't forget to track your tasks")
  Future<void> scheduleGeneralReminder({
    required String title,
    required String message,
    required DateTime reminderTime,
  }) async {
    if (kIsWeb || !_initialized) return;
    if (!await areNotificationsEnabled()) return;

    final notificationId = _notificationIdCounter++;
    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'general_reminder_channel',
      'General Reminders',
      channelDescription: 'General app reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      notificationId,
      title,
      message,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    Logger.i('Scheduled general reminder $notificationId at $scheduledDate');
  }

  /// Schedule daily reminder to use the app
  Future<void> scheduleDailyReminder() async {
    if (kIsWeb || !_initialized) return;
    if (!await areNotificationsEnabled()) return;

    // Schedule for 9 AM daily
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 9, 0);
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await scheduleGeneralReminder(
      title: 'Don\'t forget to track your tasks today!',
      message: 'Open Cherry Tomato to manage your tasks and start a Pomodoro session.',
      reminderTime: scheduledTime,
    );
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (kIsWeb || !_initialized) return;
    await _notifications.cancelAll();
    Logger.i('Cancelled all notifications');
  }
}

