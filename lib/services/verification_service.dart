import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles verification code lifecycle in the `profiles` table using the
/// Supabase client (no admin/service role).
class VerificationService {
  VerificationService._();
  static final instance = VerificationService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Set a verification code on the authenticated user's profile by id.
  /// Creates the row if missing.
  Future<void> setCodeForUser({
    required String userId,
    required String email,
    String? username,
    required String code,
    required DateTime expiresAt,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'email': email,
      if (username != null && username.trim().isNotEmpty)
        'username': username.trim(),
      'verification_code': code,
      'code_expiry': expiresAt.toIso8601String(),
      'is_verified': false,
      'provider': 'email',
    });
  }

  /// Fetch a profile by email (used for verification lookup).
  Future<Map<String, dynamic>?> fetchProfileByEmail(String email) async {
    final row = await _client
        .from('profiles')
        .select('id, email, verification_code, code_expiry, is_verified')
        .eq('email', email)
        .maybeSingle();
    return row as Map<String, dynamic>?;
  }

  /// Set a verification code by email (may require permissive RLS for unauthenticated users).
  Future<void> setCodeByEmail({
    required String email,
    required String code,
    required DateTime expiresAt,
  }) async {
    await _client
        .from('profiles')
        .update({
          'verification_code': code,
          'code_expiry': expiresAt.toIso8601String(),
        })
        .eq('email', email);
  }

  /// Clear code and mark verified by user id.
  Future<void> clearCodeForUser(String userId) async {
    await _client
        .from('profiles')
        .update({
          'verification_code': null,
          'code_expiry': null,
          'is_verified': true,
        })
        .eq('id', userId);
  }

  /// Clear code by email.
  Future<void> clearCodeByEmail(String email) async {
    await _client
        .from('profiles')
        .update({
          'verification_code': null,
          'code_expiry': null,
          'is_verified': true,
        })
        .eq('email', email);
  }
}