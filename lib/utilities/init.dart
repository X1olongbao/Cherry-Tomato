import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/profile_service.dart';
import '../services/task_service.dart';
import '../services/system_notification_service.dart';
import '../services/task_reminder_service.dart';
import 'constants.dart';
import 'logger.dart';

/// Call this during app startup (before runApp) to initialize
/// Supabase, SQLite, and start the sync service.
Future<void> initializeBackend() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (for OTP and Google Sign-In)
  try {
    await Firebase.initializeApp();
    Logger.i('Firebase initialized');
  } catch (e) {
    Logger.e('Firebase initialization failed: $e');
  }

  // Initialize Supabase client
  try {
    await Supabase.initialize(
      url: Constants.supabaseUrl,
      anonKey: Constants.supabaseAnonKey,
      authFlowType: AuthFlowType.pkce,
    );
    // Load profile for current user (if any)
    await ProfileService.instance.refreshCurrentUserProfile();
    Logger.i('Supabase initialized');
  } catch (e) {
    Logger.e('Supabase initialization failed: $e');
  }

  // Initialize local database
  await DatabaseService.instance.init();

  // Initialize notification service
  await SystemNotificationService.instance.init();

  // Start task reminder service
  TaskReminderService.instance.start();

  // Schedule daily general reminder
  await SystemNotificationService.instance.scheduleDailyReminder();

  // Start connectivity-based sync service
  SyncService.instance.start();
  Logger.i('Backend services started');

  // Optionally listen to auth changes to trigger sync after login/logout
  AuthService.instance.authStateChanges.listen((user) async {
    if (user != null) {
      SyncService.instance.syncUnsyncedSessionsForCurrentUser();
      // Refresh profile display name when user logs in
      ProfileService.instance.refreshCurrentUserProfile();
      // Refresh tasks to show only current user's tasks
      await TaskService.instance.refreshActiveTasks();
      // Reschedule task reminders for logged in user
      TaskReminderService.instance.start();
      Logger.i('Auth state: user logged in');
    } else {
      // Clear profile display name when user logs out
      ProfileService.instance.displayName.value = null;
      // Clear tasks when user logs out
      TaskService.instance.activeTasks.value = [];
      // Stop task reminder service
      TaskReminderService.instance.stop();
      Logger.i('Auth state: user logged out');
    }
  });
}