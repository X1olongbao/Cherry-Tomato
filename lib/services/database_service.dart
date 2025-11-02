import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/pomodoro_session.dart';

/// Manages local SQLite storage for Pomodoro sessions.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'cherry_tomato.db';
  static const _dbVersion = 1;
  static const _table = 'sessions';
  final _uuid = const Uuid();

  Database? _db;
  bool _useInMemory = false;
  final List<PomodoroSession> _mem = [];

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
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            duration INTEGER NOT NULL,
            completed_at INTEGER NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          );
        ''');
      },
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
      // Replace if id exists
      _mem.removeWhere((e) => e.id == s.id);
      _mem.add(s);
      return s;
    }
    await _database.insert(_table, s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
      _table,
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
      _table,
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
      _table,
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
      _table,
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
    await _database.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}