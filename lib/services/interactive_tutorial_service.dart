import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage interactive tutorial state
class InteractiveTutorialService {
  static final InteractiveTutorialService _instance = InteractiveTutorialService._internal();
  factory InteractiveTutorialService() => _instance;
  InteractiveTutorialService._internal();

  static InteractiveTutorialService get instance => _instance;

  // Tutorial steps
  static const String stepWelcome = 'welcome';
  static const String stepCreateTask = 'create_task';
  static const String stepStartTimer = 'start_timer';
  static const String stepCompleteTask = 'complete_task';
  static const String stepViewCalendar = 'view_calendar';
  static const String stepViewStats = 'view_stats';
  static const String stepCompleted = 'completed';

  String _currentStep = stepWelcome;
  bool _isActive = false;

  String get currentStep => _currentStep;
  bool get isActive => _isActive;

  Future<bool> shouldShowTutorial(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'interactive_tutorial_completed_$userId';
    return !(prefs.getBool(key) ?? false);
  }

  Future<void> startTutorial() async {
    _isActive = true;
    _currentStep = stepWelcome;
  }

  Future<void> completeStep(String step) async {
    _currentStep = step;
  }

  Future<void> completeTutorial(String userId) async {
    _isActive = false;
    final prefs = await SharedPreferences.getInstance();
    final key = 'interactive_tutorial_completed_$userId';
    await prefs.setBool(key, true);
  }

  Future<void> skipTutorial(String userId) async {
    await completeTutorial(userId);
  }
}
