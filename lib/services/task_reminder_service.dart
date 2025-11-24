import 'dart:async';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/system_notification_service.dart';
import '../services/auth_service.dart';
import '../utilities/logger.dart';

/// Service for managing task reminders
class TaskReminderService {
  TaskReminderService._();
  static final TaskReminderService instance = TaskReminderService._();

  Timer? _checkTimer;
  Timer? _deliverTimer;
  bool _isRunning = false;

  /// Start checking for tasks that need reminders
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _checkAndScheduleReminders();
    Logger.i('TaskReminderService started');
    // Check every hour for tasks that need reminders
    _checkTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _checkAndScheduleReminders();
    });
    // Deliver due reminders frequently as a fallback
    _deliverTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pollAndDeliverDueReminders();
    });
  }

  /// Stop checking for reminders
  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _deliverTimer?.cancel();
    _deliverTimer = null;
    _isRunning = false;
    Logger.i('TaskReminderService stopped');
  }

  /// Check all tasks and schedule reminders for those due soon
  Future<void> _checkAndScheduleReminders() async {
    final user = AuthService.instance.currentUser;
    try {
      final tasks = await DatabaseService.instance.getTasks(userId: user?.id);
      final now = DateTime.now();

      for (final task in tasks) {
        if (task.status == TaskStatus.done) continue;
        DateTime? dueDate;
        if (task.dueAt != null) {
          dueDate = DateTime.fromMillisecondsSinceEpoch(task.dueAt!, isUtc: false);
        } else if ((task.clockTime ?? '').isNotEmpty) {
          final parts = (task.clockTime ?? '').split(' ');
          if (parts.length == 2) {
            final hm = parts[0].split(':');
            if (hm.length == 2) {
              final h = int.tryParse(hm[0]) ?? 0;
              final m = int.tryParse(hm[1]) ?? 0;
              final isPm = parts[1].toUpperCase() == 'PM';
              var h24 = h % 12 + (isPm ? 12 : 0);
              if (!isPm && h == 12) h24 = 0;
              var candidate = DateTime(now.year, now.month, now.day, h24, m);
              if (candidate.isBefore(now)) {
                candidate = candidate.add(const Duration(days: 1));
              }
              dueDate = candidate;
            }
          }
        }
        if (dueDate == null) continue;
        final timeUntilDue = dueDate.difference(now);

        // Check if we need to schedule reminders
        await _scheduleTaskReminders(task, timeUntilDue);
      }
    } catch (e) {
      Logger.e('Failed to check and schedule reminders: $e');
    }
  }

  /// Schedule reminders for a task based on due date
  Future<void> _scheduleTaskReminders(Task task, Duration timeUntilDue) async {
    final user = AuthService.instance.currentUser;

    // Get existing reminders for this task
    final existingReminders = await DatabaseService.instance.getTaskReminders(task.id);

    // Cancel existing reminders
    for (final reminder in existingReminders) {
      final notificationId = reminder['notification_id'] as int?;
      if (notificationId != null) {
        await SystemNotificationService.instance.cancelTaskReminder(notificationId);
      }
    }
    await DatabaseService.instance.deleteTaskReminders(task.id);

    // Don't schedule if task is already overdue by more than 1 day
    if (timeUntilDue.inDays < -1) return;

    final now = DateTime.now();
    // Calculate dueDate from either dueAt or clockTime
    DateTime? dueDate;
    if (task.dueAt != null) {
      dueDate = DateTime.fromMillisecondsSinceEpoch(task.dueAt!, isUtc: false);
    } else if ((task.clockTime ?? '').isNotEmpty) {
      final parts = (task.clockTime ?? '').split(' ');
      if (parts.length == 2) {
        final hm = parts[0].split(':');
        if (hm.length == 2) {
          final h = int.tryParse(hm[0]) ?? 0;
          final m = int.tryParse(hm[1]) ?? 0;
          final isPm = parts[1].toUpperCase() == 'PM';
          var h24 = h % 12 + (isPm ? 12 : 0);
          if (!isPm && h == 12) h24 = 0;
          var candidate = DateTime(now.year, now.month, now.day, h24, m);
          if (candidate.isBefore(now)) {
            candidate = candidate.add(const Duration(days: 1));
          }
          dueDate = candidate;
        }
      }
    }
    if (dueDate == null) return;

    // Removed: due_today 9 AM reminder

    // Schedule "24 hours before" reminder (exactly 24 hours before due time)
    final dayBeforeReminderTime = dueDate.subtract(const Duration(days: 1));
    if (dayBeforeReminderTime.isAfter(now)) {
      final notificationId = await SystemNotificationService.instance.scheduleTaskReminder(
        taskId: task.id,
        taskTitle: task.title,
        reminderTime: dayBeforeReminderTime,
        reminderType: 'due_day_before',
        customMessage: '"${task.title}" is due tomorrow.',
      );
      await DatabaseService.instance.insertTaskReminder(
        taskId: task.id,
        userId: task.userId ?? user?.id,
        reminderType: 'due_day_before',
        reminderTime: dayBeforeReminderTime,
        notificationId: notificationId,
      );
      Logger.i('Scheduled due_day_before reminder for task ${task.id}');
    }

    // Schedule "1 hour before" reminder (exactly 1 hour before due time)
    if (dueDate.isAfter(now)) {
      final oneHourBeforeReminderTime = dueDate.subtract(const Duration(hours: 1));
      // Only schedule if it's at least 1 minute in the future
      if (oneHourBeforeReminderTime.isAfter(now.add(const Duration(minutes: 1)))) {
        final notificationId = await SystemNotificationService.instance.scheduleTaskReminder(
          taskId: task.id,
          taskTitle: task.title,
          reminderTime: oneHourBeforeReminderTime,
          reminderType: 'due_soon',
          customMessage: 'Task "${task.title}" is due in 1 hour.',
        );
        await DatabaseService.instance.insertTaskReminder(
          taskId: task.id,
          userId: task.userId ?? user?.id,
          reminderType: 'due_soon',
          reminderTime: oneHourBeforeReminderTime,
          notificationId: notificationId,
        );
        Logger.i('Scheduled due_soon reminder for task ${task.id}');
      }
    }

    if (dueDate.isAfter(now)) {
      final notificationId = await SystemNotificationService.instance.scheduleTaskReminder(
        taskId: task.id,
        taskTitle: task.title,
        reminderTime: dueDate,
        reminderType: 'due_now',
        customMessage: 'Task "${task.title}" is due now.',
      );
      await DatabaseService.instance.insertTaskReminder(
        taskId: task.id,
        userId: task.userId ?? user?.id,
        reminderType: 'due_now',
        reminderTime: dueDate,
        notificationId: notificationId,
      );
      Logger.i('Scheduled due_now reminder for task ${task.id}');
    }

    
  }

  /// Schedule reminders for a specific task (called when task is created/updated)
  Future<void> scheduleRemindersForTask(Task task) async {
    if (task.status == TaskStatus.done) return;
    final now = DateTime.now();
    DateTime? dueDate;
    if (task.dueAt != null) {
      dueDate = DateTime.fromMillisecondsSinceEpoch(task.dueAt!, isUtc: false);
    } else if ((task.clockTime ?? '').isNotEmpty) {
      final parts = (task.clockTime ?? '').split(' ');
      if (parts.length == 2) {
        final hm = parts[0].split(':');
        if (hm.length == 2) {
          final h = int.tryParse(hm[0]) ?? 0;
          final m = int.tryParse(hm[1]) ?? 0;
          final isPm = parts[1].toUpperCase() == 'PM';
          var h24 = h % 12 + (isPm ? 12 : 0);
          if (!isPm && h == 12) h24 = 0;
          var candidate = DateTime(now.year, now.month, now.day, h24, m);
          if (candidate.isBefore(now)) {
            candidate = candidate.add(const Duration(days: 1));
          }
          dueDate = candidate;
        }
      }
    }
    if (dueDate == null) return;
    final timeUntilDue = dueDate.difference(now);
    await _scheduleTaskReminders(task, timeUntilDue);
  }

  /// Cancel all reminders for a task (called when task is deleted or completed)
  Future<void> cancelRemindersForTask(String taskId) async {
    final reminders = await DatabaseService.instance.getTaskReminders(taskId);
    for (final reminder in reminders) {
      final notificationId = reminder['notification_id'] as int?;
      if (notificationId != null) {
        await SystemNotificationService.instance.cancelTaskReminder(notificationId);
      }
    }
    await DatabaseService.instance.deleteTaskReminders(taskId);
  }

  Future<void> _pollAndDeliverDueReminders() async {
    try {
      final user = AuthService.instance.currentUser;
      final rows = await DatabaseService.instance.getPendingReminders(userId: user?.id);
      for (final m in rows) {
        final id = (m['id'] ?? '').toString();
        final taskId = (m['task_id'] ?? '').toString();
        final type = (m['reminder_type'] ?? '').toString();
        final notificationId = m['notification_id'] as int?;
        final task = await DatabaseService.instance.getTaskById(taskId);
        final title = task?.title ?? 'Task';
        String? custom;
        switch (type) {
          case 'due_soon':
            custom = 'Task "$title" is due in 1 hour.';
            break;
          case 'due_today':
            custom = 'Task "$title" is due today.';
            break;
          case 'due_day_before':
            custom = '"$title" is due tomorrow.';
            break;
          case 'due_now':
            custom = 'Task "$title" is due now.';
            break;
          case 'overdue':
            custom = 'Task "$title" is overdue!';
            break;
          default:
            custom = 'Reminder: "$title"';
        }
        await SystemNotificationService.instance.showTaskReminderNow(
          taskTitle: title,
          reminderType: type,
          customMessage: custom,
        );
        if (notificationId != null) {
          await SystemNotificationService.instance.cancelTaskReminder(notificationId);
        }
        await DatabaseService.instance.markReminderSent(id);
      }
    } catch (e) {}
  }
}

