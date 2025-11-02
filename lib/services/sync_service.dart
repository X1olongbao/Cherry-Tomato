import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/pomodoro_session.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'database_service.dart';
import '../utilities/logger.dart';

/// Listens to connectivity changes and syncs unsynced sessions when online.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _sub;
  bool _isSyncing = false;
  int _retryCount = 0;

  /// Start listening to connectivity changes.
  void start() {
    _sub ??= _connectivity.onConnectivityChanged.listen((result) async {
      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi) {
        Logger.i('Connectivity: online');
        await syncUnsyncedSessionsForCurrentUser();
      } else {
        Logger.i('Connectivity: offline');
      }
    });

    // Attempt initial sync on startup
    syncUnsyncedSessionsForCurrentUser();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  /// Try to sync for the currently authenticated user.
  Future<void> syncUnsyncedSessionsForCurrentUser() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final user = AuthService.instance.currentUser;
      if (user == null) {
        Logger.w('Sync skipped: no authenticated user');
        return;
      }

      // Attach user to any local anonymous sessions
      await DatabaseService.instance.attachUserToUnsyncedSessions(user.id);

      // Fetch unsynced sessions for this user
      final unsynced = await DatabaseService.instance.getUnsyncedSessions(user.id);
      if (unsynced.isEmpty) {
        Logger.i('No unsynced sessions');
        _retryCount = 0; // reset backoff
        return;
      }

      Logger.i('Uploading ${unsynced.length} session(s) to Supabase');
      final success = await _uploadWithRetry(unsynced);
      if (success) {
        // Mark local as synced
        for (final s in unsynced) {
          await DatabaseService.instance.markSessionSynced(s.id);
        }
        Logger.i('Upload succeeded: marked sessions as synced');
        _retryCount = 0;
      } else {
        Logger.w('Upload failed: will retry later');
      }
    } catch (e) {
      Logger.e('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Upload with simple exponential backoff retry.
  Future<bool> _uploadWithRetry(List<PomodoroSession> sessions) async {
    const maxRetries = 3;
    while (_retryCount < maxRetries) {
      try {
        final ok = await ApiService.instance.uploadSessions(sessions);
        if (ok) return true;
      } catch (e) {
        Logger.w('Upload attempt ${_retryCount + 1} failed: $e');
      }
      _retryCount++;
      final delay = Duration(seconds: 1 << (_retryCount - 1)); // 1,2,4
      await Future.delayed(delay);
    }
    return false;
  }
}