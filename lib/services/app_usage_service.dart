import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AppUsageService tracks foreground usage time and persists daily totals
/// into Supabase table `app_usage` with columns:
/// - user_id (UUID)
/// - date (DATE, yyyy-MM-dd)
/// - usage_minutes (INT)
class AppUsageService {
  AppUsageService._();
  static final AppUsageService instance = AppUsageService._();

  DateTime? _sessionStart; // start time when app comes to foreground

  /// Notifies the UI with usage minutes for the current week keyed by DateTime (date only).
  /// This enables dynamic updates whenever new usage data is recorded.
  final ValueNotifier<Map<DateTime, int>> weekUsageMinutes =
      ValueNotifier<Map<DateTime, int>>({});

  /// Call when app resumes/enters foreground.
  void startSession() {
    _sessionStart = DateTime.now();
  }

  /// Call when app goes to background or is closed.
  /// Computes elapsed minutes since start and persists to the current day.
  Future<void> endSessionAndPersist() async {
    if (_sessionStart == null) return;
    final end = DateTime.now();
    final delta = end.difference(_sessionStart!);
    _sessionStart = null;

    // Only persist if at least 1 minute was used (ignore very short bursts)
    final minutes = delta.inMinutes;
    if (minutes <= 0) return;

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return; // Require auth for usage tracking

    // Normalize date to yyyy-MM-dd for storage
    final now = DateTime.now();
    final localDate = DateTime(now.year, now.month, now.day);
    final dateStr = _dateToString(localDate);

    try {
      // Fetch existing usage for this user+date to compute the new total
      final existing = await client
          .from('app_usage')
          .select('usage_minutes')
          .eq('user_id', user.id)
          .eq('date', dateStr)
          .maybeSingle();

      int newTotal = minutes;
      if (existing != null && existing is Map && existing['usage_minutes'] != null) {
        newTotal += (existing['usage_minutes'] as int);
      }

      // Upsert with conflict on (user_id, date) to ensure one row per day per user.
      // On update, also bump updated_at.
      await client
          .from('app_usage')
          .upsert({
            'user_id': user.id,
            'date': dateStr,
            'usage_minutes': newTotal,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id,date');

      // Refresh notifier so subscribers update their charts
      await refreshCurrentWeek();
    } catch (e) {
      // Swallow errors to avoid impacting user flow; consider reporting later
    }
  }

  /// Fetches usage minutes for the current week (Sunday → Saturday)
  /// and updates [weekUsageMinutes] map keyed by the exact date.
  Future<void> refreshCurrentWeek() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final days = _currentWeekDates();
    final startStr = _dateToString(days.first);
    final endStr = _dateToString(days.last);

    try {
      final rows = await client
          .from('app_usage')
          .select('date, usage_minutes')
          .eq('user_id', user.id)
          .gte('date', startStr)
          .lte('date', endStr);

      final map = <DateTime, int>{for (final d in days) d: 0};
      for (final row in rows as List) {
        final dateStr = row['date'] as String;
        final mins = (row['usage_minutes'] as int?) ?? 0;
        final date = DateTime.parse(dateStr);
        final normalized = DateTime(date.year, date.month, date.day);
        map[normalized] = mins;
      }
      weekUsageMinutes.value = map;
    } catch (e) {
      // If fetch fails, leave existing values; UI will retain previous state
    }
  }

  /// Returns the dates for the current week from Sunday to Saturday.
  List<DateTime> _currentWeekDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // In Dart, Monday=1 ... Sunday=7. We want the most recent Sunday.
    final daysFromSunday = today.weekday % 7; // Sunday → 0, Mon → 1, ...
    final sunday = today.subtract(Duration(days: daysFromSunday));
    return List.generate(7, (i) {
      final d = sunday.add(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    });
  }

  String _dateToString(DateTime d) {
    final yy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yy-$mm-$dd';
  }
}