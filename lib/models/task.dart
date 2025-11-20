import 'dart:convert';
import 'dart:math';

enum TaskPriority { high, medium, low }

enum TaskStatus { pending, inProgress, done, archived }

TaskPriority priorityFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'high':
      return TaskPriority.high;
    case 'medium':
      return TaskPriority.medium;
    case 'low':
    default:
      return TaskPriority.low;
  }
}

String priorityToString(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return 'High';
    case TaskPriority.medium:
      return 'Medium';
    case TaskPriority.low:
      return 'Low';
  }
}

TaskStatus statusFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'in_progress':
      return TaskStatus.inProgress;
    case 'done':
      return TaskStatus.done;
    case 'archived':
      return TaskStatus.archived;
    case 'pending':
    default:
      return TaskStatus.pending;
  }
}

String statusToString(TaskStatus status) {
  switch (status) {
    case TaskStatus.pending:
      return 'pending';
    case TaskStatus.inProgress:
      return 'in_progress';
    case TaskStatus.done:
      return 'done';
    case TaskStatus.archived:
      return 'archived';
  }
}

class TaskSubtask {
  final String id;
  final String text;
  final bool done;

  const TaskSubtask({
    required this.id,
    required this.text,
    required this.done,
  });

  TaskSubtask copyWith({String? id, String? text, bool? done}) => TaskSubtask(
        id: id ?? this.id,
        text: text ?? this.text,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'done': done,
      };

  factory TaskSubtask.fromJson(Map<String, dynamic> json) => TaskSubtask(
        id: (json['id'] as String?) ?? '',
        text: (json['text'] as String?) ?? '',
        done: json['done'] == true,
      );
}

class Task {
  final String id;
  final String? userId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskStatus status;
  final int createdAt; // ms since epoch
  final int? dueAt; // ms since epoch
  final int? completedAt;
  final bool manualCompleted;
  final bool autoCompleted;
  final int requiredPomodoros;
  final int requiredShortBreaks;
  final int requiredLongBreaks;
  final int pomodorosDone;
  final int shortBreaksDone;
  final int longBreaksDone;
  final int totalSubtasks;
  final int completedSubtasks;
  final String? clockTime;
  final List<TaskSubtask> subtasks;
  final bool synced;

  const Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.dueAt,
    required this.completedAt,
    required this.manualCompleted,
    required this.autoCompleted,
    required this.requiredPomodoros,
    required this.requiredShortBreaks,
    required this.requiredLongBreaks,
    required this.pomodorosDone,
    required this.shortBreaksDone,
    required this.longBreaksDone,
    required this.totalSubtasks,
    required this.completedSubtasks,
    required this.clockTime,
    required this.subtasks,
    required this.synced,
  });

  bool get isDone => status == TaskStatus.done;

  String get formattedDueDate {
    if (dueAt == null) return 'No due date';
    final dt = DateTime.fromMillisecondsSinceEpoch(dueAt!, isUtc: false);
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    final month = months[dt.month - 1];
    return "$month ${dt.day}, ${dt.year}";
  }

  String get formattedDueTime {
    if (dueAt == null) return clockTime ?? '';
    final dt = DateTime.fromMillisecondsSinceEpoch(dueAt!, isUtc: false);
    final hour12 = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${hour12.toString().padLeft(2, '0')}:$minute $period';
  }

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    TaskPriority? priority,
    TaskStatus? status,
    int? createdAt,
    int? dueAt,
    int? completedAt,
    bool? manualCompleted,
    bool? autoCompleted,
    int? requiredPomodoros,
    int? requiredShortBreaks,
    int? requiredLongBreaks,
    int? pomodorosDone,
    int? shortBreaksDone,
    int? longBreaksDone,
    int? totalSubtasks,
    int? completedSubtasks,
    String? clockTime,
    List<TaskSubtask>? subtasks,
    bool? synced,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      dueAt: dueAt ?? this.dueAt,
      completedAt: completedAt ?? this.completedAt,
      manualCompleted: manualCompleted ?? this.manualCompleted,
      autoCompleted: autoCompleted ?? this.autoCompleted,
      requiredPomodoros: requiredPomodoros ?? this.requiredPomodoros,
      requiredShortBreaks:
          requiredShortBreaks ?? this.requiredShortBreaks,
      requiredLongBreaks: requiredLongBreaks ?? this.requiredLongBreaks,
      pomodorosDone: pomodorosDone ?? this.pomodorosDone,
      shortBreaksDone: shortBreaksDone ?? this.shortBreaksDone,
      longBreaksDone: longBreaksDone ?? this.longBreaksDone,
      totalSubtasks: totalSubtasks ?? this.totalSubtasks,
      completedSubtasks: completedSubtasks ?? this.completedSubtasks,
      clockTime: clockTime ?? this.clockTime,
      subtasks: subtasks ?? this.subtasks,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'priority': priorityToString(priority).toLowerCase(),
        'status': statusToString(status),
        'created_at': createdAt,
        'due_at': dueAt,
        'completed_at': completedAt,
        'manual_completed': manualCompleted ? 1 : 0,
        'auto_completed': autoCompleted ? 1 : 0,
        'required_pomodoros': requiredPomodoros,
        'required_short_breaks': requiredShortBreaks,
        'required_long_breaks': requiredLongBreaks,
        'pomodoros_done': pomodorosDone,
        'short_breaks_done': shortBreaksDone,
        'long_breaks_done': longBreaksDone,
        'total_subtasks': totalSubtasks,
        'completed_subtasks': completedSubtasks,
        'clock_time': clockTime,
        'subtasks_json': jsonEncode(subtasks.map((s) => s.toJson()).toList()),
        'synced': synced ? 1 : 0,
      };

  Map<String, dynamic> toRemoteMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'priority': priorityToString(priority).toLowerCase(),
        'status': statusToString(status),
        'created_at': _toIsoPlus8(createdAt),
        'due_at': dueAt == null ? null : _toIsoPlus8(dueAt!),
        'completed_at': completedAt == null ? null : _toIsoPlus8(completedAt!),
        'manual_completed': manualCompleted,
        'auto_completed': autoCompleted,
        'required_pomodoros': requiredPomodoros,
        'required_short_breaks': requiredShortBreaks,
        'required_long_breaks': requiredLongBreaks,
        'pomodoros_done': pomodorosDone,
        'short_breaks_done': shortBreaksDone,
        'long_breaks_done': longBreaksDone,
        'total_subtasks': totalSubtasks,
        'completed_subtasks': completedSubtasks,
        'clock_time': clockTime,
        'subtasks_json': subtasks.map((s) => s.toJson()).toList(),
        'synced': true,
      };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as String,
        userId: map['user_id'] as String?,
        title: (map['title'] as String?) ?? '',
        description: map['description'] as String?,
        priority: priorityFromString(map['priority'] as String?),
        status: statusFromString(map['status'] as String?),
        createdAt: (map['created_at'] as num).toInt(),
        dueAt: map['due_at'] == null ? null : (map['due_at'] as num).toInt(),
        completedAt: map['completed_at'] == null
            ? null
            : (map['completed_at'] as num).toInt(),
        manualCompleted: _boolFromDb(map['manual_completed']),
        autoCompleted: _boolFromDb(map['auto_completed']),
        requiredPomodoros:
            (map['required_pomodoros'] as num? ?? 4).toInt(),
        requiredShortBreaks:
            (map['required_short_breaks'] as num? ?? 3).toInt(),
        requiredLongBreaks:
            (map['required_long_breaks'] as num? ?? 1).toInt(),
        pomodorosDone: (map['pomodoros_done'] as num? ?? 0).toInt(),
        shortBreaksDone: (map['short_breaks_done'] as num? ?? 0).toInt(),
        longBreaksDone: (map['long_breaks_done'] as num? ?? 0).toInt(),
        totalSubtasks: (map['total_subtasks'] as num? ?? 0).toInt(),
        completedSubtasks:
            (map['completed_subtasks'] as num? ?? 0).toInt(),
        clockTime: map['clock_time'] as String?,
        subtasks: _decodeSubtasks(map['subtasks_json']),
        synced: _boolFromDb(map['synced']),
      );

  factory Task.fromRemoteMap(Map<String, dynamic> map) => Task(
        id: map['id'].toString(),
        userId: map['user_id'] as String?,
        title: (map['title'] as String?) ?? '',
        description: map['description'] as String?,
        priority: priorityFromString(map['priority'] as String?),
        status: statusFromString(map['status'] as String?),
        createdAt: _fromIso(map['created_at']) ??
            DateTime.now().millisecondsSinceEpoch,
        dueAt: _fromIso(map['due_at']),
        completedAt: _fromIso(map['completed_at']),
        manualCompleted: _boolFromDb(map['manual_completed']),
        autoCompleted: _boolFromDb(map['auto_completed']),
        requiredPomodoros:
            (map['required_pomodoros'] as num? ?? 4).toInt(),
        requiredShortBreaks:
            (map['required_short_breaks'] as num? ?? 3).toInt(),
        requiredLongBreaks:
            (map['required_long_breaks'] as num? ?? 1).toInt(),
        pomodorosDone: (map['pomodoros_done'] as num? ?? 0).toInt(),
        shortBreaksDone: (map['short_breaks_done'] as num? ?? 0).toInt(),
        longBreaksDone: (map['long_breaks_done'] as num? ?? 0).toInt(),
        totalSubtasks: (map['total_subtasks'] as num? ?? 0).toInt(),
        completedSubtasks:
            (map['completed_subtasks'] as num? ?? 0).toInt(),
        clockTime: map['clock_time'] as String?,
        subtasks: _decodeSubtasks(map['subtasks_json']),
        synced: true,
      );

  static List<TaskSubtask> _decodeSubtasks(dynamic raw) {
    if (raw == null) return const [];
    try {
      if (raw is String) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((e) => TaskSubtask.fromJson(
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
            .toList();
      } else if (raw is List) {
        return raw
            .map((e) => TaskSubtask.fromJson(
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static bool _boolFromDb(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }

  static String _toIsoPlus8(int millis) {
    final dtUtc =
        DateTime.fromMillisecondsSinceEpoch(max(0, millis), isUtc: true);
    final dtPlus8 = dtUtc.add(const Duration(hours: 8));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dtPlus8.year}-${two(dtPlus8.month)}-${two(dtPlus8.day)}T'
        '${two(dtPlus8.hour)}:${two(dtPlus8.minute)}:${two(dtPlus8.second)}+08:00';
  }

  static int? _fromIso(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value).toUtc().millisecondsSinceEpoch;
      } catch (_) {
        return int.tryParse(value);
      }
    }
    return null;
  }
}

