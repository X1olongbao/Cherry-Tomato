import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/interactive_tutorial_service.dart';
import 'tutorial_overlay.dart';

/// Coordinator that manages the interactive tutorial flow
class InteractiveTutorialCoordinator extends StatefulWidget {
  final Widget child;
  final String userId;
  final GlobalKey? addTaskButtonKey;
  final GlobalKey? taskPlayButtonKey;
  final GlobalKey? calendarTabKey;
  final GlobalKey? statsTabKey;
  final GlobalKey? profileTabKey;

  const InteractiveTutorialCoordinator({
    super.key,
    required this.child,
    required this.userId,
    this.addTaskButtonKey,
    this.taskPlayButtonKey,
    this.calendarTabKey,
    this.statsTabKey,
    this.profileTabKey,
  });

  @override
  State<InteractiveTutorialCoordinator> createState() =>
      _InteractiveTutorialCoordinatorState();
}

class _InteractiveTutorialCoordinatorState
    extends State<InteractiveTutorialCoordinator> {
  final _tutorialService = InteractiveTutorialService.instance;
  bool _showOverlay = false;
  String _currentStep = '';

  @override
  void initState() {
    super.initState();
    _checkAndStartTutorial();
    // Listen for element taps
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupTapListeners();
    });
  }

  void _setupTapListeners() {
    // Add tap listeners to the highlighted elements
    // This will be called when user taps the highlighted element
    if (widget.addTaskButtonKey?.currentContext != null) {
      _addTapListener(widget.addTaskButtonKey!, InteractiveTutorialService.stepCreateTask);
    }
    if (widget.taskPlayButtonKey?.currentContext != null) {
      _addTapListener(widget.taskPlayButtonKey!, 'step_start_timer');
    }
    if (widget.calendarTabKey?.currentContext != null) {
      _addTapListener(widget.calendarTabKey!, 'step_view_calendar');
    }
    if (widget.statsTabKey?.currentContext != null) {
      _addTapListener(widget.statsTabKey!, 'step_view_stats');
    }
    if (widget.profileTabKey?.currentContext != null) {
      _addTapListener(widget.profileTabKey!, 'step_view_profile');
    }
  }

  void _addTapListener(GlobalKey key, String stepId) {
    // This method will be triggered when the user taps the highlighted element
    // The actual tap detection is handled by the TutorialOverlay allowing taps through
  }

  // Public method that can be called when user taps a highlighted element
  void onElementTapped(String stepId) {
    if (_currentStep == stepId && _showOverlay) {
      _nextStep();
    }
  }

  Future<void> _checkAndStartTutorial() async {
    final shouldShow = await _tutorialService.shouldShowTutorial(widget.userId);
    if (shouldShow && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _showWelcomeDialog();
      }
    }
  }

  Future<void> _showWelcomeDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _WelcomeDialog(
        onStart: () {
          Navigator.of(context).pop();
          _startTutorial();
        },
        onSkip: () {
          Navigator.of(context).pop();
          _tutorialService.skipTutorial(widget.userId);
        },
      ),
    );
  }

  void _startTutorial() {
    _tutorialService.startTutorial();
    setState(() {
      _showOverlay = true;
      _currentStep = InteractiveTutorialService.stepCreateTask;
    });
  }

  void _nextStep() {
    setState(() {
      switch (_currentStep) {
        case InteractiveTutorialService.stepCreateTask:
          // User tapped add task button - hide overlay temporarily
          _showOverlay = false;
          // Wait for task creation dialog, then show next step
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _showOverlay = true;
                _currentStep = 'step_task_created_info';
              });
            }
          });
          break;
        case 'step_task_created_info':
          _currentStep = 'step_start_timer';
          break;
        case 'step_start_timer':
          // User tapped play button - hide overlay temporarily
          _showOverlay = false;
          // Wait for timer page navigation, then show next step
          Future.delayed(Duration(milliseconds: 800), () {
            if (mounted) {
              setState(() {
                _showOverlay = true;
                _currentStep = 'step_timer_modes_info';
              });
            }
          });
          break;
        case 'step_timer_modes_info':
          // Navigate back to home
          _navigateToHome();
          _currentStep = 'step_back_to_home';
          break;
        case 'step_back_to_home':
          _currentStep = 'step_view_calendar';
          break;
        case 'step_view_calendar':
          // User tapped calendar tab - hide overlay temporarily
          _showOverlay = false;
          // Wait for navigation, then show next step
          Future.delayed(Duration(milliseconds: 800), () {
            if (mounted) {
              setState(() {
                _showOverlay = true;
                _currentStep = 'step_calendar_features';
              });
            }
          });
          break;
        case 'step_calendar_features':
          _currentStep = 'step_view_stats';
          break;
        case 'step_view_stats':
          // User tapped stats tab - hide overlay temporarily
          _showOverlay = false;
          // Wait for navigation, then show next step
          Future.delayed(Duration(milliseconds: 800), () {
            if (mounted) {
              setState(() {
                _showOverlay = true;
                _currentStep = 'step_stats_features';
              });
            }
          });
          break;
        case 'step_stats_features':
          _currentStep = 'step_view_profile';
          break;
        case 'step_view_profile':
          // User tapped profile tab - hide overlay temporarily
          _showOverlay = false;
          // Wait for navigation, then show next step
          Future.delayed(Duration(milliseconds: 800), () {
            if (mounted) {
              setState(() {
                _showOverlay = true;
                _currentStep = 'step_profile_features';
              });
            }
          });
          break;
        case 'step_profile_features':
          _currentStep = 'step_privacy_settings';
          break;
        case 'step_privacy_settings':
          _currentStep = 'step_app_blocker_info';
          break;
        case 'step_app_blocker_info':
          _currentStep = 'step_notifications_info';
          break;
        case 'step_notifications_info':
          // Navigate back to home
          _navigateToHome();
          _currentStep = 'step_back_to_home_final';
          break;
        case 'step_back_to_home_final':
          _completeTutorial();
          break;
        default:
          _completeTutorial();
      }
    });
  }

  void _navigateToHome() {
    // Navigate back to home screen
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _autoTapElement(GlobalKey? key) {
    if (key?.currentContext == null) return;
    
    // Find and trigger the onTap callback
    bool _findAndTriggerTap(Element element) {
      final widget = element.widget;
      
      // Check if this widget has an onTap
      if (widget is GestureDetector && widget.onTap != null) {
        widget.onTap!();
        return true;
      } else if (widget is InkWell && widget.onTap != null) {
        widget.onTap!();
        return true;
      } else if (widget is IconButton && widget.onPressed != null) {
        widget.onPressed!();
        return true;
      } else if (widget is ElevatedButton && widget.onPressed != null) {
        widget.onPressed!();
        return true;
      } else if (widget is TextButton && widget.onPressed != null) {
        widget.onPressed!();
        return true;
      }
      
      // Recursively search children
      bool found = false;
      element.visitChildElements((child) {
        if (!found) {
          found = _findAndTriggerTap(child);
        }
      });
      return found;
    }
    
    _findAndTriggerTap(key!.currentContext as Element);
  }

  void _completeTutorial() {
    _tutorialService.completeTutorial(widget.userId);
    setState(() {
      _showOverlay = false;
    });
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => _CompletionDialog(
        onDone: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showOverlay && _tutorialService.isActive)
          _buildCurrentOverlay(),
      ],
    );
  }

  Widget _buildCurrentOverlay() {
    switch (_currentStep) {
      case InteractiveTutorialService.stepCreateTask:
        return _buildInfoOverlay(
          title: 'Create Tasks 📝',
          description:
              'Use the "Add Task" button to create tasks with:\n\n'
              '• Task title and description\n'
              '• Deadline & time\n'
              '• Priority level (High/Medium/Low)\n'
              '• Optional subtasks\n\n'
              'Manage your tasks:\n'
              '• Tap to expand details\n'
              '• Long press to edit/delete\n'
              '• Check box to mark complete\n'
              '• Tap ▶ to start Pomodoro',
          icon: Icons.task_alt,
          iconColor: Color(0xFF4CAF50),
          onNext: _nextStep,
        );
        break;
      case 'step_task_created_info':
        return _buildInfoOverlay(
          title: 'Pomodoro Timer 🍅',
          description:
              'Start focused work sessions with the Pomodoro technique!\n\n'
              'Timer Modes:\n'
              '🍅 Classic: 25 min work / 5 min break\n'
              '📚 Long Study: 50 min work / 10 min break\n'
              '⚡ Quick Task: 15 min work / 5 min break\n'
              '⚙️ Custom: Set your own times\n\n'
              'The timer runs in a 4-session cycle with automatic breaks and focus checks!',
          icon: Icons.timer,
          iconColor: Color(0xFFE53935),
          onNext: _nextStep,
        );
        break;
      case 'step_start_timer':
        return _buildInfoOverlay(
          title: 'Calendar View 📅',
          description:
              'Let\'s explore the Calendar feature!\n\n'
              'Tap "Next" to navigate to the Calendar page.',
          icon: Icons.calendar_month,
          iconColor: Color(0xFFFF6F00),
          onNext: () {
            // Auto-navigate to calendar
            _autoTapElement(widget.calendarTabKey);
            Future.delayed(Duration(milliseconds: 800), () {
              _nextStep();
            });
          },
        );
        break;
      case 'step_timer_modes_info':
        return _buildInfoOverlay(
          title: 'Calendar Features 📅',
          description:
              'You\'re now on the Calendar page!\n\n'
              '📅 Scroll through days horizontally\n'
              '◀️ ▶️ Use arrows to navigate\n'
              '🔴 Red dots show days with tasks\n'
              '📍 Auto-centers on today\n'
              '👆 Tap any day to see its tasks\n'
              '▶️ Start Pomodoro from calendar\n\n'
              'Perfect for planning your week!',
          icon: Icons.calendar_month,
          iconColor: Color(0xFFFF6F00),
          onNext: _nextStep,
        );
        break;
      case 'step_back_to_home':
        return _buildInfoOverlay(
          title: 'Statistics Dashboard 📊',
          description:
              'Let\'s check out your productivity stats!\n\n'
              'Tap "Next" to navigate to the Stats page.',
          icon: Icons.analytics,
          iconColor: Color(0xFF2196F3),
          onNext: () {
            // Auto-navigate to stats
            _autoTapElement(widget.statsTabKey);
            Future.delayed(Duration(milliseconds: 800), () {
              _nextStep();
            });
          },
        );
        break;
      case 'step_view_calendar':
        return _buildInfoOverlay(
          title: 'Statistics Dashboard 📊',
          description:
              'You\'re now on the Stats page!\n\n'
              '🔥 Daily Streak Counter\n'
              '   - Consecutive days of activity\n'
              '   - Resets after 48 hours\n\n'
              '📊 Weekly Screen Time Graph\n'
              '   - Bar chart of daily usage\n'
              '   - Total and average time\n\n'
              '📋 Task Overview\n'
              '   - Pending tasks count\n'
              '   - Completed sessions\n\n'
              'Track your progress!',
          icon: Icons.analytics,
          iconColor: Color(0xFF2196F3),
          onNext: _nextStep,
        );
        break;
      case 'step_calendar_features':
        return _buildInfoOverlay(
          title: 'Profile & Settings 👤',
          description:
              'Let\'s explore your profile settings!\n\n'
              'Tap "Next" to navigate to the Profile page.',
          icon: Icons.person,
          iconColor: Color(0xFF00BCD4),
          onNext: () {
            // Auto-navigate to profile
            _autoTapElement(widget.profileTabKey);
            Future.delayed(Duration(milliseconds: 800), () {
              _nextStep();
            });
          },
        );
        break;
      case 'step_view_stats':
        return _buildInfoOverlay(
          title: 'Profile & Settings 👤',
          description:
              'You\'re now on the Profile page!\n\n'
              '👤 Edit Profile\n'
              '   - Change display name\n'
              '   - Upload profile picture\n\n'
              '🔒 Privacy & Security\n'
              '   - Change password\n'
              '   - Enable app blocker\n'
              '   - Manage notifications\n\n'
              '🚪 Logout\n'
              '   - Sign out of account',
          icon: Icons.person,
          iconColor: Color(0xFF00BCD4),
          onNext: _nextStep,
        );
        break;
      case 'step_stats_features':
        return _buildInfoOverlay(
          title: 'Privacy & Security 🔒',
          description:
              'Important settings in Privacy & Security:\n\n'
              '🔐 Change Password\n'
              '   - Update your password\n'
              '   - Password strength indicator\n\n'
              '🔔 Notifications\n'
              '   - Enable/disable notifications\n'
              '   - Task reminders\n'
              '   - Session alerts\n\n'
              '🚫 App Blocker\n'
              '   - Block distracting apps\n'
              '   - Stay focused during sessions',
          icon: Icons.security,
          iconColor: Color(0xFF9C27B0),
          onNext: _nextStep,
        );
        break;
      case 'step_view_profile':
        return _buildInfoOverlay(
          title: '🚫 App Blocker Feature',
          description:
              'The App Blocker helps you stay focused!\n\n'
              'How to use:\n'
              '1. Go to Privacy & Security\n'
              '2. Toggle "App Blocker" ON\n'
              '3. Grant permissions:\n'
              '   • Usage Access\n'
              '   • Overlay Permission\n'
              '4. Tap "App Selection"\n'
              '5. Scan and select apps to block\n\n'
              'During Pomodoro sessions:\n'
              '✓ Selected apps are blocked\n'
              '✓ Persistent overlay appears\n'
              '✓ Can\'t bypass until session ends\n\n'
              'Perfect for eliminating distractions!',
          icon: Icons.block,
          iconColor: Color(0xFF9C27B0),
          onNext: _nextStep,
        );
        break;
      case 'step_profile_features':
        return _buildInfoOverlay(
          title: '🔔 Notifications',
          description:
              'Stay updated with notifications!\n\n'
              'How to enable:\n'
              '1. Go to Privacy & Security\n'
              '2. Toggle "Notifications" ON\n'
              '3. Grant notification permission\n\n'
              'You\'ll receive:\n'
              '• Task deadline reminders\n'
              '• Session completion alerts\n'
              '• Focus check notifications\n\n'
              'View notifications:\n'
              '• Tap bell icon on home screen\n'
              '• See unread badge counter\n'
              '• Mark as read/unread',
          icon: Icons.notifications_active,
          iconColor: Color(0xFFFF5722),
          onNext: () {
            // Navigate back to home
            _navigateToHome();
            Future.delayed(Duration(milliseconds: 800), () {
              _nextStep();
            });
          },
        );
        break;
      case 'step_privacy_settings':
        return _buildInfoOverlay(
          title: 'Tutorial Complete! 🎉',
          description:
              'Congratulations! You\'ve learned about:\n\n'
              '✓ Creating and managing tasks\n'
              '✓ Pomodoro timer modes\n'
              '✓ Calendar view\n'
              '✓ Statistics dashboard\n'
              '✓ Profile settings\n'
              '✓ App Blocker feature\n'
              '✓ Notifications\n\n'
              'You\'re ready to boost your productivity!\n\n'
              'Pro Tips:\n'
              '💡 Start with small tasks\n'
              '🎯 Set realistic goals\n'
              '⏸️ Take breaks seriously\n'
              '📊 Review stats weekly',
          icon: Icons.celebration,
          iconColor: Color(0xFFE53935),
          onNext: _completeTutorial,
        );
        break;
    }
    return const SizedBox.shrink();
  }

  Widget _buildInfoOverlay({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onNext,
  }) {
    return Stack(
      children: [
        // Dark overlay
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.85),
          ),
        ),
        // Info card - minimal and compact
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 24.w),
              padding: EdgeInsets.all(16.w),
              constraints: BoxConstraints(maxWidth: 320.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 6.h),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50.w,
                    height: 50.w,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 26.sp,
                      color: iconColor,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: iconColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 10.h),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Got it!',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Icon(Icons.arrow_forward, size: 16.sp),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeDialog extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onSkip;

  const _WelcomeDialog({
    required this.onStart,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: Container(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 8.h),
                  ),
                ],
              ),
              child: Icon(
                Icons.waving_hand,
                size: 40.sp,
                color: const Color(0xFFFFB300),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Welcome to Cherry Tomato! 🍅',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Let\'s take a hands-on tour! You\'ll actually use each feature as we guide you. Don\'t worry, we\'ll show you exactly what to tap!',
              style: TextStyle(
                fontSize: 15.sp,
                color: Colors.black87,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Color(0xFFFFE0B2).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: Color(0xFFFFB300).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFFFB300), size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'You can only tap highlighted elements during the tutorial',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                child: Text(
                  'Start Tutorial',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: onSkip,
              child: Text(
                'Skip for now',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionDialog extends StatelessWidget {
  final VoidCallback onDone;

  const _CompletionDialog({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      child: Container(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFCDD2), Color(0xFFEF9A9A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE53935).withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 8.h),
                  ),
                ],
              ),
              child: Icon(
                Icons.celebration,
                size: 40.sp,
                color: const Color(0xFFE53935),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Tutorial Complete! 🎉',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Congratulations! You\'ve learned:\n\n'
              '✓ Creating tasks\n'
              '✓ Starting Pomodoro sessions\n'
              '✓ Using the calendar\n'
              '✓ Viewing statistics\n'
              '✓ App blocker feature\n'
              '✓ Notifications\n\n'
              'You\'re ready to boost your productivity!',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black87,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                child: Text(
                  'Let\'s Go!',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
