import 'dart:convert';

/// Data model representing a single Pomodoro session.
/// Stored locally in SQLite and synced to Supabase when online.
class PomodoroSession {
  /// UUIDv4 string primary key
  final String id;

  /// Supabase `auth.user.id`, nullable if created offline before login
  final String? userId;

  /// Related task id (nullable for historical sessions)
  final String? taskId;

  /// Cached task name/dates to render history cards even if the task is gone
  final String? taskName;
  final int? taskCreatedAt;
  final int? taskDueAt;

  /// Duration of the session in minutes
  final int duration;

  /// Session type label (pomodoro, short_break, long_break)
  final String sessionType;

  /// Custom duration for custom modes
  final int? customDuration;

  /// Preset mode used: 'classic', 'longStudy', 'quickTask', 'custom'
  final String? presetMode;

  /// Unix timestamp in milliseconds when the session completed
  final int completedAt;

  /// Timestamp when the task was finished (if applicable)
  final int? finishedAt;

  /// Whether this session represents a completed task
  final bool taskCompleted;

  /// Whether this record has been synced to the server
  final bool synced;

  const PomodoroSession({
    required this.id,
    required this.userId,
    required this.taskId,
    required this.taskName,
    required this.taskCreatedAt,
    required this.taskDueAt,
    required this.duration,
    required this.sessionType,
    required this.customDuration,
    this.presetMode,
    required this.completedAt,
    required this.finishedAt,
    required this.taskCompleted,
    required this.synced,
  });

  PomodoroSession copyWith({
    String? id,
    String? userId,
    String? taskId,
    String? taskName,
    int? taskCreatedAt,
    int? taskDueAt,
    int? duration,
    String? sessionType,
    int? customDuration,
    String? presetMode,
    int? completedAt,
    int? finishedAt,
    bool? taskCompleted,
    bool? synced,
  }) {
    return PomodoroSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      taskId: taskId ?? this.taskId,
      taskName: taskName ?? this.taskName,
      taskCreatedAt: taskCreatedAt ?? this.taskCreatedAt,
      taskDueAt: taskDueAt ?? this.taskDueAt,
      duration: duration ?? this.duration,
      sessionType: sessionType ?? this.sessionType,
      customDuration: customDuration ?? this.customDuration,
      presetMode: presetMode ?? this.presetMode,
      completedAt: completedAt ?? this.completedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      taskCompleted: taskCompleted ?? this.taskCompleted,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'task_id': taskId,
      'task_name': taskName,
      'task_created_at': taskCreatedAt,
      'task_due_at': taskDueAt,
      'duration': duration,
      'session_type': sessionType,
      'custom_duration': customDuration,
      'preset_mode': presetMode,
      'completed_at': completedAt,
      'finished_at': finishedAt,
      'task_completed': taskCompleted ? 1 : 0,
      'synced': synced ? 1 : 0,
    };
  }

  String _toIsoPlus8(int millis) {
    final dtUtc =
        DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    final dtPlus8 = dtUtc.add(const Duration(hours: 8));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dtPlus8.year}-${two(dtPlus8.month)}-${two(dtPlus8.day)}T'
        '${two(dtPlus8.hour)}:${two(dtPlus8.minute)}:${two(dtPlus8.second)}+08:00';
  }

  /// Map used for Supabase insert. Do not include `synced`.
  Map<String, dynamic> toRemoteMap() {
    return {
      'id': id,
      'user_id': userId,
      'task_id': taskId,
      'task_name': taskName,
      'task_created_at':
          taskCreatedAt == null ? null : _toIsoPlus8(taskCreatedAt!),
      'task_due_at': taskDueAt == null ? null : _toIsoPlus8(taskDueAt!),
      'duration': duration,
      'session_type': sessionType,
      'custom_duration': customDuration,
      'preset_mode': presetMode,
      'completed_at': _toIsoPlus8(completedAt),
      'finished_at': finishedAt == null ? null : _toIsoPlus8(finishedAt!),
      'task_completed': taskCompleted,
    };
  }

  factory PomodoroSession.fromMap(Map<String, dynamic> map) {
    return PomodoroSession(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      taskId: map['task_id'] as String?,
      taskName: map['task_name'] as String?,
      taskCreatedAt: _parseTimestamp(map['task_created_at']),
      taskDueAt: _parseTimestamp(map['task_due_at']),
      duration: (map['duration'] as num).toInt(),
      sessionType: (map['session_type'] as String?) ?? 'pomodoro',
      customDuration: _maybeNum(map['custom_duration']),
      presetMode: map['preset_mode'] as String?,
      completedAt: _parseTimestamp(map['completed_at']) ??
          DateTime.now().millisecondsSinceEpoch,
      finishedAt: _parseTimestamp(map['finished_at']),
      taskCompleted: (map['task_completed'] as int? ?? 0) == 1,
      synced: (map['synced'] as int) == 1,
    );
  }

  static int? _maybeNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static int? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String && value.isNotEmpty) {
      try {
        final parsed = DateTime.parse(value);
        return parsed.toUtc().millisecondsSinceEpoch;
      } catch (_) {
        return int.tryParse(value);
      }
    }
    return null;
  }

  String toJson() => jsonEncode(toMap());

  factory PomodoroSession.fromJson(String source) =>
      PomodoroSession.fromMap(jsonDecode(source) as Map<String, dynamic>);
}