import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'constants.dart';
import 'logger.dart';

/// Call this during app startup (before runApp) to initialize
/// Supabase, SQLite, and start the sync service.
Future<void> initializeBackend() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase client
  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnonKey,
    authFlowType: AuthFlowType.pkce,
  );
  Logger.i('Supabase initialized');

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
    } else {
      Logger.i('Auth state changed: user logged out');
    }
  });
}