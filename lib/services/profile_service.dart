import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches profile data (e.g., username) from Supabase `public.profiles`.
class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  final ValueNotifier<String?> displayName = ValueNotifier<String?>(null);

  SupabaseClient get _client => Supabase.instance.client;

  Future<String?> _fetchUsernameForUser(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .maybeSingle();
      if (row is Map && row['username'] is String) {
        final u = (row['username'] as String).trim();
        if (u.isNotEmpty) return u;
      }
    } catch (_) {}
    return null;
  }

  /// Resolve and update displayName for the current auth user.
  Future<void> refreshCurrentUserProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      displayName.value = null;
      return;
    }
    final username = await _fetchUsernameForUser(userId);
    displayName.value = username; // may be null; UI will fallback
  }
}