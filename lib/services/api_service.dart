import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pomodoro_session.dart';
import '../models/task.dart';
import '../utilities/constants.dart';
import '../utilities/logger.dart';

/// Handles remote operations against Supabase tables.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Upload a batch of sessions to Supabase.
  /// Returns true if upload succeeded.
  Future<bool> uploadSessions(List<PomodoroSession> sessions) async {
    if (sessions.isEmpty) return true;
    try {
      // Ensure payload includes synced=true as required by server-side schema/logic
      final payload = sessions.map((s) {
        final m = s.toRemoteMap();
        // Remote table uses BIGSERIAL id; omit client UUID id
        m.remove('id');
        // Explicitly mark as synced for remote table
        m['synced'] = true;
        return m;
      }).toList();
      
      final userId = sessions.first.userId;
      if (userId == null || userId.isEmpty) {
        throw const RemoteFailure(message: 'Missing user_id on sessions payload');
      }
      Logger.i('Uploading ${payload.length} sessions for user $userId');

      // Insert rows and select inserted values for verification
      final inserted = await _client
          .from(Constants.remoteSessionTable)
          .insert(payload)
          .select();

      final insertedCount = (inserted is List) ? inserted.length : 0;

      // Consider upload successful if at least one row was affected
      return insertedCount > 0;
    } on PostgrestException catch (e) {
      Logger.e('Upload sessions failed: ${e.message}');
      throw RemoteFailure(message: e.message);
    } on SocketException {
      Logger.e('Upload sessions failed: network connection error');
      throw const RemoteFailure(message: 'Network connection error');
    } catch (e) {
      Logger.e('Upload sessions failed: $e');
      throw RemoteFailure(message: e.toString());
    }
  }

  /// Fetch sessions for a given `user_id` from Supabase.
  /// Returns a list marked as synced.
  Future<List<PomodoroSession>> fetchSessionsForUser(String userId) async {
    try {
      final rows = await _client
          .from(Constants.remoteSessionTable)
          .select()
          .eq('user_id', userId)
          .order('completed_at', ascending: false);
      return (rows as List<dynamic>).map((r) {
        final m = r as Map<String, dynamic>;
        final normalized = {
          'id': (m['id']).toString(),
          'user_id': m['user_id'],
          'task_id': m['task_id'],
          'task_name': m['task_name'],
          'task_created_at': m['task_created_at'],
          'task_due_at': m['task_due_at'],
          'duration': m['duration'],
          'session_type': m['session_type'],
          'custom_duration': m['custom_duration'],
          'preset_mode': m['preset_mode'],
          'completed_at': m['completed_at'],
          'finished_at': m['finished_at'],
          'task_completed':
              (m['task_completed'] == true || m['task_completed'] == 1) ? 1 : 0,
          'synced': 1,
        };
        return PomodoroSession.fromMap(
            Map<String, dynamic>.from(normalized));
      }).toList();
    } on PostgrestException catch (e) {
      throw RemoteFailure(message: e.message);
    } on SocketException {
      throw const RemoteFailure(message: 'Network connection error');
    } catch (e) {
      throw RemoteFailure(message: e.toString());
    }
  }

  /// Upload a single session to Supabase and return true on success.
  Future<bool> uploadSession(PomodoroSession session) async {
    try {
      final m = session.toRemoteMap();
      // Remote table uses BIGSERIAL id; omit client UUID id
      m.remove('id');
      m['synced'] = true;

      Logger.i('Uploading single session for user ${m['user_id']}');

      final inserted = await _client
          .from(Constants.remoteSessionTable)
          .insert(m)
          .select();

      return inserted is List && inserted.isNotEmpty;
    } on PostgrestException catch (e) {
      Logger.e('Upload single session failed: ${e.message}');
      throw RemoteFailure(message: e.message);
    } on SocketException {
      Logger.e('Upload single session failed: network connection error');
      throw const RemoteFailure(message: 'Network connection error');
    } catch (e) {
      Logger.e('Upload single session failed: $e');
      throw RemoteFailure(message: e.toString());
    }
  }

  Future<bool> uploadTask(Task task) async {
    try {
      final payload = task.toRemoteMap();
      final inserted = await _client
          .from(Constants.remoteTasksTable)
          .upsert(payload, onConflict: 'id')
          .select();
      return inserted is List && inserted.isNotEmpty;
    } on PostgrestException catch (e) {
      Logger.e('Upload task failed: ${e.message}');
      throw RemoteFailure(message: e.message);
    } on SocketException {
      throw const RemoteFailure(message: 'Network connection error');
    } catch (e) {
      throw RemoteFailure(message: e.toString());
    }
  }

  Future<List<Task>> fetchTasksForUser(String userId) async {
    try {
      final rows = await _client
          .from(Constants.remoteTasksTable)
          .select()
          .eq('user_id', userId);
      return (rows as List<dynamic>)
          .map((r) => Task.fromRemoteMap(
              Map<String, dynamic>.from(r as Map<dynamic, dynamic>)))
          .toList();
    } on PostgrestException catch (e) {
      throw RemoteFailure(message: e.message);
    } on SocketException {
      throw const RemoteFailure(message: 'Network connection error');
    } catch (e) {
      throw RemoteFailure(message: e.toString());
    }
  }

  /// Delete a task from Supabase by ID
  Future<bool> deleteTask(String taskId) async {
    try {
      await _client
          .from(Constants.remoteTasksTable)
          .delete()
          .eq('id', taskId);
      Logger.i('Task deleted from Supabase: $taskId');
      return true;
    } on PostgrestException catch (e) {
      Logger.e('Delete task failed: ${e.message}');
      throw RemoteFailure(message: e.message);
    } on SocketException {
      Logger.e('Delete task failed: network connection error');
      throw const RemoteFailure(message: 'Network connection error');
    } catch (e) {
      Logger.e('Delete task failed: $e');
      throw RemoteFailure(message: e.toString());
    }
  }
}

class RemoteFailure implements Exception {
  final String message;
  const RemoteFailure({required this.message});
  @override
  String toString() => 'RemoteFailure($message)';
}
