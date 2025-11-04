import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utilities/constants.dart';

/// Calls secure backend endpoints (e.g., Supabase Edge Functions) that use the
/// Supabase service role key to perform admin actions. Never call admin APIs
/// directly from the client.
class AdminApiService {
  AdminApiService._();
  static final AdminApiService instance = AdminApiService._();

  /// Create a Supabase Auth user with `emailConfirm: true` and optional metadata.
  /// Returns the created user's id.
  Future<String> createUser({
    required String email,
    required String password,
    Map<String, dynamic>? userMetadata,
  }) async {
    final url = Uri.parse(Constants.adminCreateUserUrl);
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'emailConfirm': true,
        if (userMetadata != null) 'userMetadata': userMetadata,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final id = data['id'] as String?;
      if (id == null || id.isEmpty) {
        throw Exception('Admin create user returned no id');
      }
      return id;
    }
    throw Exception('Admin create user failed: ${res.statusCode} ${res.body}');
  }

  /// Update a Supabase Auth user's password (admin).
  Future<void> updatePassword({
    required String userId,
    required String newPassword,
  }) async {
    final url = Uri.parse(Constants.adminUpdatePasswordUrl);
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'userId': userId,
        'password': newPassword,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception('Admin update password failed: ${res.statusCode} ${res.body}');
  }

  /// Upsert or update a profile using service role (bypasses RLS).
  /// Provide either `id` or `email` as a selector, and the `data` object to merge.
  Future<void> upsertProfile({
    String? id,
    String? email,
    required Map<String, dynamic> data,
  }) async {
    final url = Uri.parse(Constants.adminUpsertProfileUrl);
    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (id != null) 'id': id,
        if (email != null) 'email': email,
        'data': data,
      }),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    throw Exception('Admin upsert profile failed: ${res.statusCode} ${res.body}');
  }
}