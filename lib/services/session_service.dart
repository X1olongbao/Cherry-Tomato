import '../models/pomodoro_session.dart';
import '../models/session_type.dart';
import '../models/task.dart';
import 'auth_service.dart';
import 'database_service.dart';
import 'sync_service.dart';
import 'api_service.dart';
import 'notification_service.dart';
import 'task_service.dart';

/// High-level helpers to record and read Pomodoro sessions.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  /// Record a completed Pomodoro/Break session.
  Future<PomodoroSession> recordCompletedSession({
    required SessionType sessionType,
    required int durationMinutes,
    Task? task,
    bool manualCompletion = false,
    String? presetMode,
  }) async {
    final user = AuthService.instance.currentUser;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    Task? freshTask = task;
    bool taskCompleted = false;

    if (task != null) {
      // Reload from database for latest counters
      freshTask = await TaskService.instance.getTask(task.id) ?? task;
    }

    if (freshTask != null) {
      final singlePomodoroTask =
          sessionType == SessionType.pomodoro && freshTask.requiredPomodoros <= 1;
      if (manualCompletion || singlePomodoroTask) {
        freshTask =
            await TaskService.instance.markManualCompletion(freshTask);
        taskCompleted = true;
      } else {
        final progress =
            await TaskService.instance.applySessionProgress(freshTask, sessionType);
        if (progress != null) {
          freshTask = progress.task;
          taskCompleted = progress.justCompleted;
        }
      }
    }

    final existing = await DatabaseService.instance.getSessions(userId: user?.id);
    final session = PomodoroSession(
      id: '',
      userId: user?.id,
      taskId: freshTask?.id,
      taskName: freshTask?.title,
      taskCreatedAt: freshTask?.createdAt,
      taskDueAt: freshTask?.dueAt,
      duration: durationMinutes,
      sessionType: sessionType.dbValue,
      customDuration: null,
      presetMode: presetMode,
      completedAt: nowMs,
      finishedAt: nowMs,
      taskCompleted: taskCompleted,
      synced: false,
    );

    final saved = await DatabaseService.instance.insertSession(session);

    if (existing.isEmpty) {
      NotificationService.instance.addFirstPomodoroCongrats();
    }

    // Add a generic in-app notification for each completed Pomodoro
    if (taskCompleted) {
      NotificationService.instance.addPomodoroCompleted(
        taskName: freshTask?.title,
      );
      // Update streaks only after the task is completed and session stored
      try {
        final all = await DatabaseService.instance.getSessions(userId: user?.id);
        final dates = <DateTime>{};
        for (final s in all) {
          final dt = DateTime.fromMillisecondsSinceEpoch(s.completedAt);
          dates.add(DateTime(dt.year, dt.month, dt.day));
        }
        var streak = 0;
        var cur = DateTime.now();
        cur = DateTime(cur.year, cur.month, cur.day);
        if (!dates.contains(cur)) {
          final y = cur.subtract(const Duration(days: 1));
          if (dates.contains(y)) {
            cur = y;
          } else {
            cur = DateTime(1970);
          }
        }
        while (dates.contains(cur)) {
          streak++;
          cur = cur.subtract(const Duration(days: 1));
        }
        if (streak == 7 || streak == 14 || streak == 30) {
          NotificationService.instance.addStreakMilestone(streak);
        }
      } catch (_) {}
    }

    await SyncService.instance.syncUnsyncedSessionsForCurrentUser();
    return saved;
  }

  Future<PomodoroSession?> recordTaskSnapshot(Task task) async {
    return recordCompletedSession(
      sessionType: SessionType.pomodoro,
      durationMinutes: task.requiredPomodoros * 25,
      task: task,
      manualCompletion: true,
    );
  }

  /// List all sessions for the current user. If not logged in, returns all local sessions.
  Future<List<PomodoroSession>> listSessionsForCurrentUser() async {
    final user = AuthService.instance.currentUser;
    return DatabaseService.instance.getSessions(userId: user?.id);
  }

  /// Merge local and remote sessions for the current user.
  /// - Local includes unsynced and synced entries
  /// - Remote includes server synced entries
  /// De-duplicates by `(duration, completedAt)` signature to avoid showing
  /// duplicates when local UUIDs differ from remote BIGSERIAL ids.
  Future<List<PomodoroSession>> mergedSessionsForCurrentUser() async {
    final user = AuthService.instance.currentUser;
    final local = await DatabaseService.instance.getSessions(userId: user?.id);
    if (user == null) return local;
    List<PomodoroSession> remote = [];
    try {
      remote = await ApiService.instance.fetchSessionsForUser(user.id);
    } catch (_) {
      // If remote fetch fails (offline, server), still show local sessions.
      remote = [];
    }
    final bySignature = <String, PomodoroSession>{};
    for (final s in local) {
      final sig = '${s.taskId ?? ''}|${s.duration}|${s.completedAt}';
      bySignature[sig] = s;
    }
    for (final s in remote) {
      final sig = '${s.taskId ?? ''}|${s.duration}|${s.completedAt}';
      final existing = bySignature[sig];
      if (existing == null) {
        bySignature[sig] = s;
      } else {
        // Prefer remote for already-synced entries; keep local if it's unsynced
        if (existing.synced) {
          bySignature[sig] = s;
        }
      }
    }
    final all = bySignature.values
        .where((s) => s.taskCompleted)
        .toList();
    all.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return all;
  }
}
