import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/pomodoro_session.dart';
import '../models/task.dart';

/// Manages local SQLite storage for Pomodoro sessions.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'cherry_tomato.db';
  static const _dbVersion = 2;
  static const _sessionTable = 'sessions';
  static const _taskTable = 'tasks';
  final _uuid = const Uuid();

  Database? _db;
  bool _useInMemory = false;
  final List<PomodoroSession> _mem = [];
  final List<Task> _memTasks = [];

  /// Initialize the database (idempotent). Call during app bootstrap.
  Future<void> init() async {
    if (_db != null || _useInMemory) return;
    // On web, sqflite/path_provider are not supported. Use in-memory fallback.
    if (kIsWeb) {
      _useInMemory = true;
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);
    _db = await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: (db, version) async => _createTables(db),
      onUpgrade: (db, oldVersion, newVersion) async =>
          _upgradeTables(db, oldVersion),
    );
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('Database not initialized. Call DatabaseService.instance.init() first.');
    }
    return db;
  }

  /// Insert a new session; generates a UUID if missing.
  Future<PomodoroSession> insertSession(PomodoroSession session) async {
    final s = session.id.isEmpty ? session.copyWith(id: _uuid.v4()) : session;
    if (_useInMemory) {
      _mem.removeWhere((e) => e.id == s.id);
      _mem.add(s);
      return s;
    }
    await _database.insert(_sessionTable, s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return s;
  }

  /// Read all sessions; optionally filter by user.
  Future<List<PomodoroSession>> getSessions({String? userId}) async {
    if (_useInMemory) {
      final list = _mem.where((s) => userId == null || s.userId == userId).toList();
      list.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return list;
    }
    final maps = await _database.query(
      _sessionTable,
      where: userId == null ? null : 'user_id = ?',
      whereArgs: userId == null ? null : [userId],
      orderBy: 'completed_at DESC',
    );
    return maps.map((m) => PomodoroSession.fromMap(m)).toList();
  }

  /// Read all unsynced sessions for the given userId.
  Future<List<PomodoroSession>> getUnsyncedSessions(String userId) async {
    if (_useInMemory) {
      final list = _mem.where((s) => s.synced == false && s.userId == userId).toList();
      list.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return list;
    }
    final maps = await _database.query(
      _sessionTable,
      where: 'synced = 0 AND user_id = ?',
      whereArgs: [userId],
      orderBy: 'completed_at DESC',
    );
    return maps.map((m) => PomodoroSession.fromMap(m)).toList();
  }

  /// Mark session as synced.
  Future<void> markSessionSynced(String id) async {
    if (_useInMemory) {
      final idx = _mem.indexWhere((s) => s.id == id);
      if (idx != -1) {
        _mem[idx] = _mem[idx].copyWith(synced: true);
      }
      return;
    }
    await _database.update(
      _sessionTable,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Attach current user id to all locally created (userless) sessions.
  Future<void> attachUserToUnsyncedSessions(String userId) async {
    if (_useInMemory) {
      for (var i = 0; i < _mem.length; i++) {
        final s = _mem[i];
        if (s.userId == null || s.userId!.isEmpty) {
          _mem[i] = s.copyWith(userId: userId);
        }
      }
      return;
    }
    await _database.update(
      _sessionTable,
      {'user_id': userId},
      where: 'user_id IS NULL OR user_id = ""',
    );
  }

  /// Delete a session by id.
  Future<void> deleteSession(String id) async {
    if (_useInMemory) {
      _mem.removeWhere((s) => s.id == id);
      return;
    }
    await _database.delete(_sessionTable, where: 'id = ?', whereArgs: [id]);
  }

  // -------- TASKS --------

  Future<Task> insertTask(Task task) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final candidate = task.id.isEmpty
        ? task.copyWith(id: _uuid.v4(), createdAt: now)
        : task;
    if (_useInMemory) {
      _memTasks.removeWhere((t) => t.id == candidate.id);
      _memTasks.add(candidate);
      return candidate;
    }
    await _database.insert(_taskTable, candidate.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return candidate;
  }

  Future<List<Task>> getTasks({TaskStatus? status}) async {
    if (_useInMemory) {
      final list = _memTasks
          .where((t) => status == null || t.status == status)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    final maps = await _database.query(
      _taskTable,
      where: status == null ? null : 'status = ?',
      whereArgs:
          status == null ? null : [statusToString(status)],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Task.fromMap(m)).toList();
  }

  Future<List<Task>> getUnsyncedTasks(String userId) async {
    if (_useInMemory) {
      final list = _memTasks
          .where((t) => t.synced == false && t.userId == userId)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    final maps = await _database.query(
      _taskTable,
      where: 'synced = 0 AND user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Task.fromMap(m)).toList();
  }

  Future<void> markTaskSynced(String id) async {
    if (_useInMemory) {
      final idx = _memTasks.indexWhere((t) => t.id == id);
      if (idx != -1) {
        _memTasks[idx] = _memTasks[idx].copyWith(synced: true);
      }
      return;
    }
    await _database.update(
      _taskTable,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> attachUserToUnsyncedTasks(String userId) async {
    if (_useInMemory) {
      for (var i = 0; i < _memTasks.length; i++) {
        final t = _memTasks[i];
        if (t.userId == null || t.userId!.isEmpty) {
          _memTasks[i] = t.copyWith(userId: userId, synced: false);
        }
      }
      return;
    }
    await _database.update(
      _taskTable,
      {'user_id': userId},
      where: 'user_id IS NULL OR user_id = ""',
    );
  }

  Future<Task?> getTaskById(String id) async {
    if (_useInMemory) {
      try {
        return _memTasks.firstWhere((t) => t.id == id);
      } catch (_) {
        return null;
      }
    }
    final maps = await _database.query(
      _taskTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Task.fromMap(maps.first);
  }

  Future<Task> updateTask(Task task) async {
    if (_useInMemory) {
      final idx = _memTasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        _memTasks[idx] = task;
      } else {
        _memTasks.add(task);
      }
      return task;
    }
    await _database.update(
      _taskTable,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
    return task;
  }

  Future<void> deleteTask(String id) async {
    if (_useInMemory) {
      _memTasks.removeWhere((t) => t.id == id);
      return;
    }
    await _database.delete(_taskTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTaskFields(
      String id, Map<String, Object?> fields) async {
    if (_useInMemory) {
      final idx = _memTasks.indexWhere((t) => t.id == id);
      if (idx != -1) {
        final existing = _memTasks[idx];
        _memTasks[idx] = existing.copyWith(
          title: fields['title'] as String? ?? existing.title,
          description:
              fields['description'] as String? ?? existing.description,
          status: fields['status'] != null
              ? statusFromString(fields['status'] as String?)
              : existing.status,
          dueAt: fields['due_at'] as int? ?? existing.dueAt,
          completedAt:
              fields['completed_at'] as int? ?? existing.completedAt,
          manualCompleted:
              fields['manual_completed'] != null ? (fields['manual_completed'] as int) == 1 : existing.manualCompleted,
          autoCompleted:
              fields['auto_completed'] != null ? (fields['auto_completed'] as int) == 1 : existing.autoCompleted,
          pomodorosDone:
              fields['pomodoros_done'] as int? ?? existing.pomodorosDone,
          shortBreaksDone:
              fields['short_breaks_done'] as int? ?? existing.shortBreaksDone,
          longBreaksDone:
              fields['long_breaks_done'] as int? ?? existing.longBreaksDone,
          completedSubtasks:
              fields['completed_subtasks'] as int? ?? existing.completedSubtasks,
          totalSubtasks:
              fields['total_subtasks'] as int? ?? existing.totalSubtasks,
        );
      }
      return;
    }
    await _database.update(
      _taskTable,
      fields,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE $_sessionTable (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        task_id TEXT,
        task_name TEXT,
        task_created_at INTEGER,
        task_due_at INTEGER,
        duration INTEGER NOT NULL,
        session_type TEXT NOT NULL DEFAULT 'pomodoro',
        custom_duration INTEGER,
        completed_at INTEGER NOT NULL,
        finished_at INTEGER,
        task_completed INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE $_taskTable (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL,
        description TEXT,
        priority TEXT NOT NULL DEFAULT 'low',
        status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL,
        due_at INTEGER,
        completed_at INTEGER,
        manual_completed INTEGER NOT NULL DEFAULT 0,
        auto_completed INTEGER NOT NULL DEFAULT 0,
        required_pomodoros INTEGER NOT NULL DEFAULT 4,
        required_short_breaks INTEGER NOT NULL DEFAULT 3,
        required_long_breaks INTEGER NOT NULL DEFAULT 1,
        pomodoros_done INTEGER NOT NULL DEFAULT 0,
        short_breaks_done INTEGER NOT NULL DEFAULT 0,
        long_breaks_done INTEGER NOT NULL DEFAULT 0,
        total_subtasks INTEGER NOT NULL DEFAULT 0,
        completed_subtasks INTEGER NOT NULL DEFAULT 0,
        clock_time TEXT,
        subtasks_json TEXT,
        synced INTEGER NOT NULL DEFAULT 0
      );
    ''');
  }

  Future<void> _upgradeTables(Database db, int oldVersion) async {
    if (oldVersion < 2) {
      await _safeAddColumn(
          db, _sessionTable, 'task_id', 'TEXT');
      await _safeAddColumn(
          db, _sessionTable, 'task_name', 'TEXT');
      await _safeAddColumn(
          db, _sessionTable, 'task_created_at', 'INTEGER');
      await _safeAddColumn(
          db, _sessionTable, 'task_due_at', 'INTEGER');
      await _safeAddColumn(
          db, _sessionTable, 'session_type', "TEXT NOT NULL DEFAULT 'pomodoro'");
      await _safeAddColumn(
          db, _sessionTable, 'custom_duration', 'INTEGER');
      await _safeAddColumn(
          db, _sessionTable, 'finished_at', 'INTEGER');
      await _safeAddColumn(
          db, _sessionTable, 'task_completed', 'INTEGER NOT NULL DEFAULT 0');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_taskTable (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          title TEXT NOT NULL,
          description TEXT,
          priority TEXT NOT NULL DEFAULT 'low',
          status TEXT NOT NULL DEFAULT 'pending',
          created_at INTEGER NOT NULL,
          due_at INTEGER,
          completed_at INTEGER,
          manual_completed INTEGER NOT NULL DEFAULT 0,
          auto_completed INTEGER NOT NULL DEFAULT 0,
          required_pomodoros INTEGER NOT NULL DEFAULT 4,
          required_short_breaks INTEGER NOT NULL DEFAULT 3,
          required_long_breaks INTEGER NOT NULL DEFAULT 1,
          pomodoros_done INTEGER NOT NULL DEFAULT 0,
          short_breaks_done INTEGER NOT NULL DEFAULT 0,
          long_breaks_done INTEGER NOT NULL DEFAULT 0,
          total_subtasks INTEGER NOT NULL DEFAULT 0,
          completed_subtasks INTEGER NOT NULL DEFAULT 0,
          clock_time TEXT,
          subtasks_json TEXT,
          synced INTEGER NOT NULL DEFAULT 0
        );
      ''');
    }
  }

  Future<void> _safeAddColumn(
      Database db, String table, String column, String typeDefinition) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $typeDefinition;');
    } catch (_) {
      // ignore if column already exists
    }
  }
}