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

      // Debug payload types for the first record to catch type mismatches
      final sample = payload.first;
      Logger.i(
          '🧪 Payload sample types: id=${sample['id']?.runtimeType}, user_id=${sample['user_id']?.runtimeType}, duration=${sample['duration']?.runtimeType}, completed_at=${sample['completed_at']?.runtimeType}, synced=${sample['synced']?.runtimeType}');

      // Determine userId for logging and verification
      final userId = sessions.first.userId;
      if (userId == null || userId.isEmpty) {
        throw const RemoteFailure(message: 'Missing user_id on sessions payload');
      }

      // Before count (debug)
      final before = await fetchSessionsForUser(userId);
      Logger.i('📡 Remote before upload count for user $userId: ${before.length}');

      // Insert rows and select inserted values for verification
      final inserted = await _client
          .from(Constants.remoteSessionTable)
          .insert(payload)
          .select();

      final insertedCount = (inserted is List) ? inserted.length : 0;
      Logger.i('📤 Supabase upsert affected rows: $insertedCount');

      // After count (debug)
      final after = await fetchSessionsForUser(userId);
      Logger.i('📡 Remote after upload count for user $userId: ${after.length}');

      // Consider upload successful if at least one row was affected
      return insertedCount > 0;
    } on PostgrestException catch (e) {
      // Server-side failure
      Logger.e('❌ Supabase PostgrestException: ${e.message}');
      throw RemoteFailure(message: e.message);
    } on SocketException {
      Logger.e('❌ Network connection error during upload');
      throw const RemoteFailure(message: 'Network connection error');
    } catch (e) {
      Logger.e('❌ Unknown upload error: $e');
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

      Logger.i(
          '🧪 Single payload types: user_id=${m['user_id']?.runtimeType}, duration=${m['duration']?.runtimeType}, completed_at=${m['completed_at']?.runtimeType}, synced=${m['synced']?.runtimeType}');

      final inserted = await _client
          .from(Constants.remoteSessionTable)
          .insert(m)
          .select();

      final ok = inserted is List && inserted.isNotEmpty;
      final affected = inserted is List ? inserted.length : 0;
      Logger.i('📤 Insert for session ${session.id} affected rows: $affected');
      return ok;
    } on PostgrestException catch (e) {
      Logger.e('❌ Supabase PostgrestException: ${e.message}');
      throw RemoteFailure(message: e.message);
    } on SocketException {
      Logger.e('❌ Network connection error during upload');
      throw const RemoteFailure(message: 'Network connection error');
    } catch (e) {
      Logger.e('❌ Unknown upload error: $e');
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
      Logger.e('❌ Upload task failed: ${e.message}');
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
}

class RemoteFailure implements Exception {
  final String message;
  const RemoteFailure({required this.message});
  @override
  String toString() => 'RemoteFailure($message)';
}