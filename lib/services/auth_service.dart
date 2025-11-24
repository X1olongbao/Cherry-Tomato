import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

/// Handles Supabase email/password authentication.
/// Provides signup, signin, signout, and current user retrieval.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  String? _usernameFrom(User user) {
    final meta = user.userMetadata;
    if (meta is Map<String, dynamic>) {
      final u = meta['username'];
      if (u is String && u.trim().isNotEmpty) return u.trim();
    }
    return null;
  }

  /// Sign up a new user using email/password.
  /// Optionally attaches a `username` to Supabase auth user metadata at creation time.
  /// Throws [AuthFailure] on known errors, e.g. duplicate email.
  Future<AppUser> signUp({required String email, required String password, String? username}) async {
    try {
      final meta = (username != null && username.trim().isNotEmpty)
          ? {'username': username.trim()}
          : null;
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: meta,
      );
      final user = res.user;
      if (user == null) {
        throw const AuthFailure(code: AuthFailureCode.unknown, message: 'Signup failed: no user returned');
      }
      // Prefer reading username from server response; fallback to provided username
      final resolvedUsername = _usernameFrom(user) ?? username?.trim();
      return AppUser(id: user.id, email: user.email, username: resolvedUsername);
    } on AuthException catch (e) {
      // Map common Supabase auth errors
      final message = e.message.toLowerCase();
      if (message.contains('already registered')) {
        throw const AuthFailure(code: AuthFailureCode.duplicateEmail, message: 'Email already registered');
      }
      throw AuthFailure(code: AuthFailureCode.unknown, message: e.message);
    } on SocketException {
      throw const AuthFailure(code: AuthFailureCode.network, message: 'Network connection error');
    } catch (e) {
      throw AuthFailure(code: AuthFailureCode.unknown, message: e.toString());
    }
  }

  /// Sign in using email/password.
  /// Throws [AuthFailure] on wrong password, network errors, etc.
  Future<AppUser> signIn({required String email, required String password}) async {
    try {
      final res = await _client.auth.signInWithPassword(email: email, password: password);
      final user = res.user;
      if (user == null) {
        throw const AuthFailure(code: AuthFailureCode.unknown, message: 'Login failed: no user returned');
      }
      return AppUser(id: user.id, email: user.email, username: _usernameFrom(user));
    } on AuthException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('invalid login')) {
        throw const AuthFailure(code: AuthFailureCode.wrongPassword, message: 'Invalid email or password');
      }
      throw AuthFailure(code: AuthFailureCode.unknown, message: e.message);
    } on SocketException {
      throw const AuthFailure(code: AuthFailureCode.network, message: 'Network connection error');
    } catch (e) {
      throw AuthFailure(code: AuthFailureCode.unknown, message: e.toString());
    }
  }

  /// Sign out current user.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on SocketException {
      throw const AuthFailure(code: AuthFailureCode.network, message: 'Network connection error');
    } catch (e) {
      throw AuthFailure(code: AuthFailureCode.unknown, message: e.toString());
    }
  }

  /// Current logged-in user, or null.
  AppUser? get currentUser {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return AppUser(id: user.id, email: user.email, username: _usernameFrom(user));
  }

  /// Listen to auth state changes.
  Stream<AppUser?> get authStateChanges {
    return _client.auth.onAuthStateChange.map((event) {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      return AppUser(id: user.id, email: user.email, username: _usernameFrom(user));
    });
  }
}

/// Error code set for known authentication failures.
class AuthFailureCode {
  static const String wrongPassword = 'wrong_password';
  static const String duplicateEmail = 'duplicate_email';
  static const String network = 'network_error';
  static const String unknown = 'unknown_error';
}

/// Lightweight failure object thrown by the auth methods for precise handling.
class AuthFailure implements Exception {
  final String code;
  final String message;
  const AuthFailure({required this.code, required this.message});

  @override
  String toString() => 'AuthFailure(code: $code, message: $message)';
}