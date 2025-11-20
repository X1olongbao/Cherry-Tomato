import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pomodoro_session.dart';
import '../models/task.dart';
import 'task_service.dart';
import 'api_service.dart';
import 'database_service.dart';
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
        Logger.i('🌐 Internet connected');
        await syncUnsyncedSessionsForCurrentUser();
      } else {
        Logger.i('📱 Internet disconnected');
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
  /// Shows SnackBar notifications for user feedback.
  /// Only runs if the user is logged in.
  Future<void> manualSync(BuildContext context) async {
    final supabaseUserId = Supabase.instance.client.auth.currentUser?.id;
    if (supabaseUserId == null || supabaseUserId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Please log in to sync sessions'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Show syncing message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Syncing sessions...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    Logger.i('🔄 Manual sync initiated');
    
    try {
      await syncUnsyncedSessionsForCurrentUser();
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync complete!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Logger.e('❌ Manual sync failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Try to sync unsynced sessions for the currently authenticated user.
  /// Includes comprehensive logging and session count debugging.
  Future<void> syncUnsyncedSessionsForCurrentUser() async {
    if (_isSyncing) {
      Logger.i('🔄 Sync already in progress, skipping');
      return;
    }
    _isSyncing = true;
    
    try {
      // Use exact Supabase user UUID as required
      final supabaseUserId = Supabase.instance.client.auth.currentUser?.id;
      if (supabaseUserId == null || supabaseUserId.isEmpty) {
        Logger.w('⚠️ Sync skipped: no authenticated user');
        return;
      }

      Logger.i('🔁 Starting sync...');

      // Attach user to any local anonymous tasks/sessions
      await DatabaseService.instance.attachUserToUnsyncedTasks(supabaseUserId);
      await DatabaseService.instance.attachUserToUnsyncedSessions(supabaseUserId);

      // First sync tasks so FK constraints succeed
      final unsyncedTasks =
          await DatabaseService.instance.getUnsyncedTasks(supabaseUserId);
      Logger.i('🧾 Unsynced tasks: ${unsyncedTasks.length}');
      for (final task in unsyncedTasks) {
        Logger.i('📤 Uploading task ${task.id}');
        final uploaded = await _uploadTaskWithRetry(task);
        if (uploaded) {
          await DatabaseService.instance.markTaskSynced(task.id);
          Logger.i('✅ Task ${task.id} uploaded');
        } else {
          Logger.w('⚠️ Task ${task.id} not uploaded — will keep as unsynced');
        }
      }

      // Fetch unsynced sessions for this user
      final unsynced =
          await DatabaseService.instance.getUnsyncedSessions(supabaseUserId);
      
      // Debug: Show session counts
      final allLocalSessions = await DatabaseService.instance.getSessions(userId: supabaseUserId);
      Logger.i('📊 SQLite unsynced sessions: ${unsynced.length}');
      Logger.i('📦 Found ${unsynced.length} unsynced sessions');
      Logger.i('📊 SQLite total sessions: ${allLocalSessions.length}');
      
      if (unsynced.isNotEmpty) {
        Logger.i('📤 Uploading ${unsynced.length} session(s) to Supabase');
        for (final session in unsynced) {
          Logger.i('📤 Uploading session ${session.id}');
          final uploaded = await _uploadSingleWithRetry(session);
          if (uploaded) {
            await DatabaseService.instance.markSessionSynced(session.id);
            Logger.i('✅ Session ${session.id} uploaded');
          } else {
            Logger.w(
                '⚠️ Session ${session.id} not uploaded — will keep as unsynced');
          }
        }
        Logger.i('🎉 Session sync complete');
      } else {
        Logger.i('✅ No unsynced sessions found');
      }

      // After syncing, reconcile local with remote to remove entries deleted on server
      await _reconcileTasksWithRemote(supabaseUserId);
      await _reconcileLocalWithRemote(supabaseUserId);
    } catch (e) {
      Logger.e('❌ Sync error: $e');
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
        Logger.w('❌ Sync failed for task ${task.id}: API returned false');
      } catch (e) {
        Logger.w('❌ Upload attempt ${attempt + 1}/$maxRetries failed for task ${task.id}: $e');
      }
      attempt++;
      if (attempt < maxRetries) {
        final delay = Duration(seconds: 1 << (attempt - 1));
        Logger.i('⏳ Retrying task ${task.id} in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
    }
    Logger.e('❌ All retry attempts failed for task ${task.id}. Will retry later.');
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
        Logger.w('❌ Sync failed for session ${session.id}: API returned false');
      } catch (e) {
        Logger.w('❌ Upload attempt ${attempt + 1}/$maxRetries failed: $e');
        Logger.w('❌ Sync failed for session ${session.id}: $e');
      }
      attempt++;
      if (attempt < maxRetries) {
        final delay = Duration(seconds: 1 << (attempt - 1)); // 1,2 seconds
        Logger.i('⏳ Retrying in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
    }
    Logger.e('❌ All retry attempts failed for ${session.id}. Will retry on next internet connection.');
    return false;
  }

  /// Reconcile local synced sessions with the current remote state.
  /// If a local session (synced == true) is missing remotely, delete it locally.
  Future<void> _reconcileLocalWithRemote(String userId) async {
    try {
      Logger.i('🧮 Reconciling local with remote for user $userId');
      final remote = await ApiService.instance.fetchSessionsForUser(userId);
      final remoteSigs = remote
          .map((s) => '${s.taskId ?? ''}|${s.duration}|${s.completedAt}')
          .toSet();
      final local = await DatabaseService.instance.getSessions(userId: userId);
      final localSigs = local
          .map((s) => '${s.taskId ?? ''}|${s.duration}|${s.completedAt}')
          .toSet();

      int removed = 0;
      for (final s in local) {
        final sig = '${s.taskId ?? ''}|${s.duration}|${s.completedAt}';
        if (s.synced && !remoteSigs.contains(sig)) {
          await DatabaseService.instance.deleteSession(s.id);
          removed++;
          Logger.i('🗑️ Removed local session ${s.id} (not present remotely)');
        }
      }

      int added = 0;
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
          added++;
          Logger.i('📥 Cached remote session locally (sig=$sig)');
        }
      }
      Logger.i('🧹 Reconciliation complete. Removed $removed, added $added.');
    } catch (e) {
      Logger.w('⚠️ Reconciliation skipped due to error: $e');
    }
  }
  
  Future<void> _reconcileTasksWithRemote(String userId) async {
    try {
      Logger.i('🧮 Reconciling tasks for user $userId');
      final remoteTasks = await ApiService.instance.fetchTasksForUser(userId);
      final localTasks = await DatabaseService.instance.getTasks(userId: userId);
      final localIds = localTasks.map((t) => t.id).toSet();

      int added = 0;
      for (final task in remoteTasks) {
        if (!localIds.contains(task.id)) {
          await DatabaseService.instance.insertTask(task.copyWith(synced: true));
          added++;
        }
      }
      Logger.i('🧹 Task reconciliation complete. Added $added remote tasks.');
      if (added > 0) {
        unawaited(TaskService.instance.refreshActiveTasks());
      }
    } catch (e) {
      Logger.w('⚠️ Task reconciliation skipped due to error: $e');
    }
  }
}