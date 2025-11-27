import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import '../models/session_type.dart';
import 'auth_service.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'task_reminder_service.dart';
import '../utilities/logger.dart';

class TaskProgressResult {
  final Task task;
  final bool justCompleted;
  const TaskProgressResult({required this.task, required this.justCompleted});
}

class TaskService {
  TaskService._();
  static final TaskService instance = TaskService._();

  final ValueNotifier<List<Task>> activeTasks =
      ValueNotifier<List<Task>>(<Task>[]);

  Future<void> refreshActiveTasks() async {
    final user = AuthService.instance.currentUser;
    final tasks = await DatabaseService.instance.getTasks(userId: user?.id);
    final active = tasks
        .where((t) =>
            t.status == TaskStatus.pending || t.status == TaskStatus.inProgress)
        .toList()
      ..sort((a, b) => a.dueAt == null || b.dueAt == null
          ? a.createdAt.compareTo(b.createdAt)
          : a.dueAt!.compareTo(b.dueAt!));
    activeTasks.value = active;
  }

  Future<Task> createTask({
    required String title,
    String? description,
    required TaskPriority priority,
    required int createdAt,
    int? dueAt,
    String? clockTime,
    List<TaskSubtask>? subtasks,
  }) async {
    final user = AuthService.instance.currentUser;
    final task = Task(
      id: '',
      userId: user?.id,
      title: title,
      description: description,
      priority: priority,
      status: TaskStatus.pending,
      createdAt: createdAt,
      dueAt: dueAt,
      completedAt: null,
      manualCompleted: false,
      autoCompleted: false,
      requiredPomodoros: 4,
      requiredShortBreaks: 3,
      requiredLongBreaks: 1,
      pomodorosDone: 0,
      shortBreaksDone: 0,
      longBreaksDone: 0,
      totalSubtasks: subtasks?.length ?? 0,
      completedSubtasks:
          subtasks?.where((element) => element.done).length ?? 0,
      clockTime: clockTime,
      subtasks: subtasks ?? const [],
      synced: false,
    );
    final saved = await DatabaseService.instance.insertTask(task);
    await refreshActiveTasks();
    // Schedule reminders for the new task
    await TaskReminderService.instance.scheduleRemindersForTask(saved);
    return saved;
  }

  Future<Task?> getTask(String id) async {
    return DatabaseService.instance.getTaskById(id);
  }

  Future<Task> updateTaskDetails({
    required Task existing,
    required String title,
    TaskPriority? priority,
    DateTime? due,
    String? clockTime,
    List<TaskSubtask>? subtasks,
  }) async {
    final newSubtasks = subtasks ?? existing.subtasks;
    final updated = existing.copyWith(
      title: title,
      priority: priority ?? existing.priority,
      dueAt: due?.millisecondsSinceEpoch,
      clockTime: clockTime ?? existing.clockTime,
      subtasks: newSubtasks,
      totalSubtasks: newSubtasks.length,
      completedSubtasks: newSubtasks.where((s) => s.done).length,
      synced: false,
    );
    await DatabaseService.instance.updateTask(updated);
    await refreshActiveTasks();
    if (updated.dueAt != null && updated.status != TaskStatus.done) {
      unawaited(TaskReminderService.instance.scheduleRemindersForTask(updated));
    }
    return updated;
  }

  Future<void> deleteTask(String id) async {
    // Cancel reminders before deleting task
    await TaskReminderService.instance.cancelRemindersForTask(id);
    
    // Delete from local database
    await DatabaseService.instance.deleteTask(id);
    
    // Delete from Supabase if user is logged in
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        await ApiService.instance.deleteTask(id);
      }
    } catch (e) {
      Logger.w('Failed to delete task from Supabase: $e');
      // Continue even if remote delete fails - local delete succeeded
    }
    
    await refreshActiveTasks();
  }

  Future<TaskProgressResult?> applySessionProgress(
      Task task, SessionType type) async {
    var updated = task;
    switch (type) {
      case SessionType.pomodoro:
        updated = updated.copyWith(
          pomodorosDone: task.pomodorosDone + 1,
          synced: false,
        );
        break;
      case SessionType.shortBreak:
        updated = updated.copyWith(
          shortBreaksDone: task.shortBreaksDone + 1,
          synced: false,
        );
        break;
      case SessionType.longBreak:
        updated = updated.copyWith(
          longBreaksDone: task.longBreaksDone + 1,
          synced: false,
        );
        break;
    }

    final meetsPomodoro =
        updated.pomodorosDone >= updated.requiredPomodoros;
    final meetsShort =
        updated.shortBreaksDone >= updated.requiredShortBreaks;
    final meetsLong =
        updated.longBreaksDone >= updated.requiredLongBreaks;
    final justCompleted =
        !task.isDone && meetsPomodoro && meetsShort && meetsLong;

    if (justCompleted) {
      updated = updated.copyWith(
        status: TaskStatus.done,
        autoCompleted: true,
        completedAt: DateTime.now().millisecondsSinceEpoch,
        synced: false,
      );
      // Cancel reminders when task is completed
      await TaskReminderService.instance.cancelRemindersForTask(updated.id);
    } else if (updated.status == TaskStatus.pending) {
      updated = updated.copyWith(
        status: TaskStatus.inProgress,
        synced: false,
      );
    }

    await DatabaseService.instance.updateTask(updated);
    await refreshActiveTasks();
    
    // Reschedule reminders if task due date exists and task is not done
    if (updated.dueAt != null && updated.status != TaskStatus.done) {
      unawaited(TaskReminderService.instance.scheduleRemindersForTask(updated));
    }

    return TaskProgressResult(task: updated, justCompleted: justCompleted);
  }

  Future<Task> markManualCompletion(Task task) async {
    final updated = task.copyWith(
      status: TaskStatus.done,
      manualCompleted: true,
      completedAt: DateTime.now().millisecondsSinceEpoch,
      synced: false,
    );
    await DatabaseService.instance.updateTask(updated);
    await refreshActiveTasks();
    // Cancel reminders when task is manually completed
    await TaskReminderService.instance.cancelRemindersForTask(updated.id);
    return updated;
  }

  Future<Task?> updateSubtasks(Task task, List<TaskSubtask> subtasks) async {
    final updated = task.copyWith(
      subtasks: subtasks,
      totalSubtasks: subtasks.length,
      completedSubtasks: subtasks.where((s) => s.done).length,
      synced: false,
    );
    await DatabaseService.instance.updateTask(updated);
    await refreshActiveTasks();
    return updated;
  }
}

