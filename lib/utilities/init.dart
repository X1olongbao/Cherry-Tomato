import 'dart:async';
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

  // Initialize Firebase (for OTP and Google Sign-In) with timeout
  try {
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        Logger.w('Firebase initialization timed out');
        throw TimeoutException('Firebase init timeout');
      },
    );
    Logger.i('Firebase initialized');
  } catch (e) {
    Logger.e('Firebase initialization failed: $e');
  }

  // Initialize Supabase client with timeout
  try {
    await Supabase.initialize(
      url: Constants.supabaseUrl,
      anonKey: Constants.supabaseAnonKey,
      authFlowType: AuthFlowType.pkce,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        Logger.w('Supabase initialization timed out');
        throw TimeoutException('Supabase init timeout');
      },
    );
    
    // Load profile for current user (if any) - non-blocking
    ProfileService.instance.refreshCurrentUserProfile().timeout(
      const Duration(seconds: 5),
    ).catchError((e) {
      Logger.w('Profile refresh failed during init: $e');
    });
    
    Logger.i('Supabase initialized');
  } catch (e) {
    Logger.e('Supabase initialization failed: $e');
  }

  // Initialize local database with timeout
  try {
    await DatabaseService.instance.init().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        Logger.e('Database initialization timed out');
        throw TimeoutException('Database init timeout');
      },
    );
  } catch (e) {
    Logger.e('Database initialization failed: $e');
  }

  // Initialize notification service (non-blocking)
  SystemNotificationService.instance.init().catchError((e) {
    Logger.e('Notification service init failed: $e');
  });

  // Start task reminder service (non-blocking)
  try {
    TaskReminderService.instance.start();
  } catch (e) {
    Logger.e('Task reminder service failed: $e');
  }

  // Schedule daily general reminder (non-blocking)
  SystemNotificationService.instance.scheduleDailyReminder().catchError((e) {
    Logger.e('Daily reminder scheduling failed: $e');
  });

  // Start connectivity-based sync service
  try {
    SyncService.instance.start();
  } catch (e) {
    Logger.e('Sync service failed: $e');
  }
  
  Logger.i('Backend services started');

  // Optionally listen to auth changes to trigger sync after login/logout
  AuthService.instance.authStateChanges.listen((user) async {
    if (user != null) {
      try {
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'last_login': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}
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
