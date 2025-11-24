import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pomodoro_session.dart';
import '../models/task.dart';
import 'task_service.dart';
import 'api_service.dart';
import 'database_service.dart';
import 'task_reminder_service.dart';
import '../utilities/logger.dart';

/// Listens to connectivity changes and syncs unsynced sessions when online.
/// Provides manual sync functionality and comprehensive logging for debugging.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _sub;
  bool _isSyncing = false;

  /// Start listening to connectivity changes and sync when internet becomes available.
  void start() {
    _sub ??= _connectivity.onConnectivityChanged.listen((result) async {
      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi) {
        await syncUnsyncedSessionsForCurrentUser();
      } else {
        Logger.w('Connectivity offline: $result');
      }
    });

    // Attempt initial sync on startup
    syncUnsyncedSessionsForCurrentUser();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  /// Manual sync function that can be called anytime to push unsynced sessions.
  /// Only runs if the user is logged in.
  Future<void> manualSync(BuildContext context) async {
    final supabaseUserId = Supabase.instance.client.auth.currentUser?.id;
    if (supabaseUserId == null || supabaseUserId.isEmpty) {
      return;
    }
    Logger.i('Manual sync started for $supabaseUserId');
    
    try {
      await syncUnsyncedSessionsForCurrentUser();
      
    } catch (e) {}
  }

  /// Try to sync unsynced sessions for the currently authenticated user.
  /// Includes comprehensive logging and session count debugging.
  Future<void> syncUnsyncedSessionsForCurrentUser() async {
    if (_isSyncing) {
      return;
    }
    _isSyncing = true;
    
    try {
      // Use exact Supabase user UUID as required
      final supabaseUserId = Supabase.instance.client.auth.currentUser?.id;
      if (supabaseUserId == null || supabaseUserId.isEmpty) {
        return;
      }

      Logger.i('Sync started for user $supabaseUserId');

      // Attach user to any local anonymous tasks/sessions
      await DatabaseService.instance.attachUserToUnsyncedTasks(supabaseUserId);
      await DatabaseService.instance.attachUserToUnsyncedSessions(supabaseUserId);

      // First sync tasks so FK constraints succeed
      final unsyncedTasks =
          await DatabaseService.instance.getUnsyncedTasks(supabaseUserId);
      Logger.i('Unsynced tasks: ${unsyncedTasks.length}');
      for (final task in unsyncedTasks) {
        Logger.i('Uploading task ${task.id}');
        final uploaded = await _uploadTaskWithRetry(task);
        if (uploaded) {
          await DatabaseService.instance.markTaskSynced(task.id);
          Logger.i('Task ${task.id} marked as synced');
        } else {
          Logger.w('Task ${task.id} upload failed');
        }
      }

      // Fetch unsynced sessions for this user
      final unsynced =
          await DatabaseService.instance.getUnsyncedSessions(supabaseUserId);
      
      // Debug: Show session counts
      final allLocalSessions = await DatabaseService.instance.getSessions(userId: supabaseUserId);
      Logger.i('Unsynced sessions: ${unsynced.length}, total local: ${allLocalSessions.length}');
      if (unsynced.isNotEmpty) {
        Logger.i('Uploading ${unsynced.length} sessions');
        for (final session in unsynced) {
          Logger.i('Uploading session ${session.id}');
          final uploaded = await _uploadSingleWithRetry(session);
          if (uploaded) {
            await DatabaseService.instance.markSessionSynced(session.id);
            Logger.i('Session ${session.id} marked as synced');
          } else {
            Logger.w('Session ${session.id} upload failed');
          }
        }
        Logger.i('Session upload batch complete');
      } else {
        Logger.i('No unsynced sessions');
      }

      // After syncing, reconcile local with remote to remove entries deleted on server
      await _reconcileTasksWithRemote(supabaseUserId);
      await _reconcileLocalWithRemote(supabaseUserId);
    } catch (e) {
      Logger.e('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Upload sessions with exponential backoff retry and detailed error logging.
  // Removed unused bulk upload retry method; single-session retry remains.

  Future<bool> _uploadTaskWithRetry(Task task) async {
    const maxRetries = 3;
    var attempt = 0;
    while (attempt < maxRetries) {
      try {
        final ok = await ApiService.instance.uploadTask(task);
        if (ok) return true;
      } catch (e) {
        Logger.w('Task upload attempt ${attempt + 1} failed: $e');
      }
      attempt++;
      if (attempt < maxRetries) {
        final delay = Duration(seconds: 1 << (attempt - 1));
        await Future.delayed(delay);
      }
    }
    return false;
  }

  /// Upload a single session with retry.
  Future<bool> _uploadSingleWithRetry(PomodoroSession session) async {
    const maxRetries = 3;
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final ok = await ApiService.instance.uploadSession(session);
        if (ok) return true;
      } catch (e) {
        Logger.w('Session upload attempt ${attempt + 1} failed: $e');
      }
      attempt++;
      if (attempt < maxRetries) {
        final delay = Duration(seconds: 1 << (attempt - 1)); // 1,2 seconds
        await Future.delayed(delay);
      }
    }
    return false;
  }

  /// Reconcile local synced sessions with the current remote state.
  /// If a local session (synced == true) is missing remotely, delete it locally.
  Future<void> _reconcileLocalWithRemote(String userId) async {
    try {
      final remote = await ApiService.instance.fetchSessionsForUser(userId);
      final remoteSigs = remote
          .map((s) => '${s.taskId ?? ''}|${s.duration}|${s.completedAt}')
          .toSet();
      final local = await DatabaseService.instance.getSessions(userId: userId);
      final localSigs = local
          .map((s) => '${s.taskId ?? ''}|${s.duration}|${s.completedAt}')
          .toSet();

      for (final s in local) {
        final sig = '${s.taskId ?? ''}|${s.duration}|${s.completedAt}';
        if (s.synced && !remoteSigs.contains(sig)) {
          await DatabaseService.instance.deleteSession(s.id);
        }
      }

      for (final r in remote) {
        final sig = '${r.taskId ?? ''}|${r.duration}|${r.completedAt}';
        if (!localSigs.contains(sig)) {
          // Cache remote session locally so it is visible offline
          await DatabaseService.instance.insertSession(
            r.copyWith(
              id: '', // generate local UUID locally
              userId: r.userId ?? userId,
              synced: true,
            ),
          );
        }
      }
    } catch (e) {
      Logger.w('Reconcile local with remote failed: $e');
    }
  }
  
  Future<void> _reconcileTasksWithRemote(String userId) async {
    try {
      final remoteTasks = await ApiService.instance.fetchTasksForUser(userId);
      final localTasks = await DatabaseService.instance.getTasks(userId: userId);
      final localIds = localTasks.map((t) => t.id).toSet();

      for (final task in remoteTasks) {
        if (!localIds.contains(task.id)) {
          final insertedTask = await DatabaseService.instance.insertTask(task.copyWith(synced: true));
          // Schedule reminders for newly synced tasks
          unawaited(TaskReminderService.instance.scheduleRemindersForTask(insertedTask));
        }
      }
      unawaited(TaskService.instance.refreshActiveTasks());
    } catch (e) {
      Logger.w('Reconcile tasks with remote failed: $e');
    }
  }
}