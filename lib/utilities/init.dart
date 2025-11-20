import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/profile_service.dart';
import 'constants.dart';
import 'logger.dart';

/// Call this during app startup (before runApp) to initialize
/// Supabase, SQLite, and start the sync service.
Future<void> initializeBackend() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (for OTP and Google Sign-In)
  try {
    await Firebase.initializeApp();
    Logger.i('✅ Firebase initialized');
  } catch (e) {
    Logger.e('❌ Firebase init failed: $e');
  }

  // Initialize Supabase client
  try {
    await Supabase.initialize(
      url: Constants.supabaseUrl,
      anonKey: Constants.supabaseAnonKey,
      authFlowType: AuthFlowType.pkce,
    );
    Logger.i('✅ Supabase initialized');
    // Load profile for current user (if any)
    await ProfileService.instance.refreshCurrentUserProfile();
  } catch (e) {
    // Gracefully handle initialization errors (invalid key, network issues)
    Logger.e('❌ Supabase client init failed: $e');
  }

  // Initialize local database
  await DatabaseService.instance.init();
  Logger.i('SQLite database initialized');

  // Start connectivity-based sync service
  SyncService.instance.start();
  Logger.i('Sync service started');

  // Optionally listen to auth changes to trigger sync after login/logout
  AuthService.instance.authStateChanges.listen((user) {
    if (user != null) {
      Logger.i('Auth state changed: user logged in, starting sync');
      SyncService.instance.syncUnsyncedSessionsForCurrentUser();
      // Refresh profile display name when user logs in
      ProfileService.instance.refreshCurrentUserProfile();
    } else {
      Logger.i('Auth state changed: user logged out');
      // Clear profile display name when user logs out
      ProfileService.instance.displayName.value = null;
    }
  });
}