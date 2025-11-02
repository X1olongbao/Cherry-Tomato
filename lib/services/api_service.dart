import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pomodoro_session.dart';
import '../utilities/constants.dart';

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
      final payload = sessions.map((s) => s.toRemoteMap()).toList();
      await _client.from(Constants.remoteTable).insert(payload);
      return true;
    } on PostgrestException catch (e) {
      // Server-side failure
      throw RemoteFailure(message: e.message);
    } on SocketException {
      throw const RemoteFailure(message: 'Network connection error');
    } catch (e) {
      throw RemoteFailure(message: e.toString());
    }
  }

  /// Fetch sessions for a given `user_id` from Supabase.
  /// Returns a list marked as synced.
  Future<List<PomodoroSession>> fetchSessionsForUser(String userId) async {
    try {
      final rows = await _client
          .from(Constants.remoteTable)
          .select()
          .eq('user_id', userId)
          .order('completed_at', ascending: false);
      return (rows as List<dynamic>).map((r) {
        final m = r as Map<String, dynamic>;
        return PomodoroSession(
          id: m['id'] as String,
          userId: m['user_id'] as String?,
          duration: (m['duration'] as num).toInt(),
          completedAt: (m['completed_at'] as num).toInt(),
          synced: true,
        );
      }).toList();
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