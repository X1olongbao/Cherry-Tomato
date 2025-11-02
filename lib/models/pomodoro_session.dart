import 'dart:convert';

/// Data model representing a single Pomodoro session.
/// Stored locally in SQLite and synced to Supabase when online.
class PomodoroSession {
  /// UUIDv4 string primary key
  final String id;

  /// Supabase `auth.user.id`, nullable if created offline before login
  final String? userId;

  /// Duration of the session in minutes (or seconds if preferred)
  final int duration;

  /// Unix timestamp in milliseconds when the session completed
  final int completedAt;

  /// Whether this record has been synced to the server
  final bool synced;

  const PomodoroSession({
    required this.id,
    required this.userId,
    required this.duration,
    required this.completedAt,
    required this.synced,
  });

  PomodoroSession copyWith({
    String? id,
    String? userId,
    int? duration,
    int? completedAt,
    bool? synced,
  }) {
    return PomodoroSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      duration: duration ?? this.duration,
      completedAt: completedAt ?? this.completedAt,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'duration': duration,
      'completed_at': completedAt,
      'synced': synced ? 1 : 0,
    };
  }

  /// Map used for Supabase insert. Do not include `synced`.
  Map<String, dynamic> toRemoteMap() {
    return {
      'id': id,
      'user_id': userId,
      'duration': duration,
      'completed_at': completedAt,
    };
  }

  factory PomodoroSession.fromMap(Map<String, dynamic> map) {
    return PomodoroSession(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      duration: (map['duration'] as num).toInt(),
      completedAt: (map['completed_at'] as num).toInt(),
      synced: (map['synced'] as int) == 1,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PomodoroSession.fromJson(String source) =>
      PomodoroSession.fromMap(jsonDecode(source) as Map<String, dynamic>);
}