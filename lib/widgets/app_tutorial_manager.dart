import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'simple_tutorial_overlay.dart';

/// Manages the complete app tutorial flow
class AppTutorialManager extends StatefulWidget {
  final Widget child;
  final String userId;
  final GlobalKey? addTaskButtonKey;
  final GlobalKey? taskPlayButtonKey;
  final GlobalKey? calendarTabKey;
  final GlobalKey? statsTabKey;
  final GlobalKey? profileTabKey;
  final GlobalKey? historyButtonKey;
  final GlobalKey? timerModeKey;
  final VoidCallback? onNavigateHome;

  const AppTutorialManager({
    super.key,
    required this.child,
    required this.userId,
    this.addTaskButtonKey,
    this.taskPlayButtonKey,
    this.calendarTabKey,
    this.statsTabKey,
    this.profileTabKey,
    this.historyButtonKey,
    this.timerModeKey,
    this.onNavigateHome,
  });

  @override
  State<AppTutorialManager> createState() => AppTutorialManagerState();
}

class AppTutorialManagerState extends State<AppTutorialManager> {
  bool _showTutorial = false;
  int _currentStep = 0;
  bool _isNavigating = false;

  final List<TutorialStep> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeTutorialSteps();
    _checkIfShouldShowTutorial();
  }

  void _initializeTutorialSteps() {
    _steps.addAll([
      // Step 1: Welcome
      TutorialStep(
        title: '🍅 Welcome to Cherry Tomato',
        description:
            'Welcome to Cherry Tomato! This tutorial will guide you through all the features to help you maximize your productivity.\n\nYou will learn about:\n• Task Management\n• Pomodoro Timer\n• Calendar and Statistics\n• App Blocker (Important)\n• Notifications',
        hasArrow: false,
      ),

      // Step 2: Add Task Button
      TutorialStep(
        title: '📝 Add Task Button',
        description:
            'Look for the "Add Task" button in the top-right corner of the home screen, next to "View History".\n\nTap it to create new tasks for your to-do list. You can add task titles, deadlines, priorities, and subtasks.',
        hasArrow: false,
        centerCard: true,
      ),

      // Step 3: Quick Task Presets
      TutorialStep(
        title: '🍅 Quick Task Presets',
        description:
            'Tap the cherry tomato icon at the bottom center of the screen to access quick task templates:\n\n• Study Session (2 hours, High priority)\n• Work Task (1 day, Medium priority)\n• Exercise (1 hour, Medium priority)\n• Reading (1 hour, Low priority)\n• Coding (3 hours, High priority)\n\nThese presets help you create tasks faster with pre-filled values.',
        hasArrow: false,
        centerCard: true,
      ),

      // Step 4: Task Management
      TutorialStep(
        title: '✅ Managing Tasks',
        description:
            'After creating tasks, you can manage them:\n\n• Tap a task to expand and view full details\n• Long press a task to edit or delete it\n• Check the box to mark a task as complete\n• Tap the play button (▶) to start a Pomodoro session\n\nCompleted tasks are automatically archived.',
        hasArrow: false,
      ),

      // Step 5: Start Pomodoro
      TutorialStep(
        title: '⏱️ Start Pomodoro Timer',
        description:
            'To start a focused work session, look for the red play button (▶) on the right side of any task card.\n\nTapping it will open the Pomodoro Timer page where you can select your preferred timer mode and start your session.',
        hasArrow: false,
        centerCard: true,
      ),

      // Step 6: Timer Modes
      TutorialStep(
        title: '⏱️ Changing Timer Modes',
        description:
            'On the timer page, you\'ll see a mode button at the bottom (shown below with green border).\n\nTap this button to switch between:\n🍅 Classic Pomodoro (25/5 min)\n📚 Long Study (50/10 min)\n⚡ Quick Task (15/5 min)\n⚙️ Custom (your own times)',
        hasArrow: false,
        centerCard: true,
        customWidget: _buildModeButtonsPreview(),
      ),

      // Step 7: Timer Features
      TutorialStep(
        title: '⏱️ Using the Timer',
        description:
            'On the Pomodoro Timer page:\n\n• Tap a mode chip to select it\n• See the countdown timer display\n• View your current task\n• Tap "Start" to begin the session\n• Use "Pause" or "Quit" as needed\n\nThe timer runs in a 4-session cycle:\nPomodoro → Short Break → Pomodoro → Short Break → Pomodoro → Short Break → Pomodoro → Long Break\n\nAfter each work session, you\'ll receive a focus check.',
        hasArrow: false,
        centerCard: true,
      ),

      // Step 8: Session History
      TutorialStep(
        title: '� Session History',
        description:
            'You can view your completed Pomodoro sessions in the Session History.\n\nThe history shows:\n• Date and time of each session\n• Task associated with the session\n• Session duration\n• Focus check results\n\nAccess it from the home page menu.',
        hasArrow: widget.historyButtonKey != null,
        arrowTargetKey: () => widget.historyButtonKey,
        showArrowAbove: true,
      ),

      // Step 9: Calendar
      TutorialStep(
        title: '📅 Calendar View',
        description:
            'The Calendar feature allows you to view and organize your tasks by date.\n\nFind the Calendar icon in the bottom navigation bar (second icon from the left) to access your task calendar.',
        hasArrow: false,
        centerCard: true,
      ),

      // Step 10: Calendar Features
      TutorialStep(
        title: '📅 Calendar Features',
        description:
            'The Calendar page provides:\n\n• Horizontal scrolling through days\n• Red dots indicating days with tasks\n• Tap any day to view its tasks\n• Start Pomodoro sessions from calendar\n• Navigate with arrow buttons\n• Auto-centers on today\n\nPerfect for planning your week ahead.',
        hasArrow: false,
      ),

      // Step 11: Statistics
      TutorialStep(
        title: '📊 Statistics Dashboard',
        description:
            'The Statistics page helps you track your productivity and progress.\n\nFind the Statistics icon in the bottom navigation bar (second icon from the right) to view your productivity metrics.',
        hasArrow: false,
        centerCard: true,
      ),

      // Step 12: Stats Features
      TutorialStep(
        title: '📊 Track Your Progress',
        description:
            'The Statistics page displays:\n\n🔥 Daily Streak Counter\n• Tracks consecutive active days\n• Resets after 48 hours of inactivity\n\n📊 Weekly Screen Time Graph\n• Visual bar chart of daily usage\n• Shows total and average time\n\n📋 Task Overview\n• Number of pending tasks\n• Count of completed sessions',
        hasArrow: false,
      ),

      // Step 13: Profile
      TutorialStep(
        title: '👤 Profile & Settings',
        description:
            'The Profile page contains your personal settings and preferences.\n\nFind the Profile icon in the bottom navigation bar (far right) to access your account settings.',
        hasArrow: false,
        centerCard: true,
      ),

      // Step 14: Profile Features
      TutorialStep(
        title: '👤 Profile Settings',
        description:
            'Your Profile page includes:\n\n• Edit your display name and profile photo\n• Access Privacy & Security settings\n• View app information\n• Logout from your account\n\nNext, we will explore the important Privacy & Security features.',
        hasArrow: false,
      ),

      // Step 15: Privacy & Security
      TutorialStep(
        title: '� Privacy & Security',
        description:
            'In your Profile page, tap "Privacy & Security" to access important settings:\n\n• Change Password\n• Enable/Disable Notifications\n• App Blocker Settings\n• App Selection for blocking\n\nLet\'s explore the App Blocker feature in detail.',
        hasArrow: false,
      ),

      // Step 16: App Blocker - IMPORTANT!
      TutorialStep(
        title: '🚫 App Blocker Setup',
        description:
            'The App Blocker is a key feature that helps maintain focus by blocking distracting applications during Pomodoro sessions.\n\nSetup instructions:\n1. Navigate to Privacy & Security in your Profile\n2. Toggle "App Blocker" to ON\n3. Grant required permissions:\n   • Usage Access Permission\n   • Overlay Permission\n4. Tap "App Selection" button\n5. Scan installed apps and select which ones to block',
        hasArrow: false,
      ),

      // Step 17: App Blocker Permissions
      TutorialStep(
        title: '� Required Permissions',
        description:
            'The App Blocker requires two permissions (grant them in Privacy & Security):\n\n📱 Usage Access Permission\nAllows the app to detect which apps you\'re using during Pomodoro sessions.\n\n🔒 Overlay Permission\nAllows the app to display a blocking overlay on top of restricted apps.\n\nBoth permissions are essential for the App Blocker to function properly.',
        hasArrow: false,
      ),

      // Step 18: App Blocker Functionality
      TutorialStep(
        title: '🚫 How App Blocker Works',
        description:
            'When the App Blocker is active during Pomodoro sessions:\n\n✓ Selected applications are completely blocked\n✓ A persistent overlay prevents access\n✓ Cannot be bypassed until the session ends\n✓ Helps eliminate distractions\n✓ Significantly improves focus and productivity\n\nThis is the most powerful feature for maintaining concentration during work sessions.',
        hasArrow: false,
      ),

      // Step 19: Notifications
      TutorialStep(
        title: '🔔 Notifications',
        description:
            'Enable notifications to receive important alerts:\n\n• Task deadline reminders\n• Session completion notifications\n• Focus check prompts\n• Break time reminders\n• Streak milestone achievements\n\nYou can enable or disable notifications in the Privacy & Security settings.',
        hasArrow: false,
      ),

      // Step 20: Complete
      TutorialStep(
        title: '🎉 Tutorial Complete',
        description:
            'Congratulations! You have completed the tutorial.\n\nYou now understand:\n✓ Creating and managing tasks\n✓ Pomodoro timer modes and cycles\n✓ Session history tracking\n✓ Calendar and Statistics features\n✓ App Blocker setup and usage\n✓ Notification settings\n\nRecommended practices:\n💡 Begin with smaller, manageable tasks\n🎯 Utilize the App Blocker for maximum focus\n⏸️ Take breaks seriously to avoid burnout\n📊 Review your statistics regularly\n\nYou are now ready to enhance your productivity with Cherry Tomato!',
        hasArrow: false,
      ),
    ]);
  }

  Future<void> _checkIfShouldShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('tutorial_completed_${widget.userId}') ?? false;
    
    if (!completed && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await _showWelcomeDialog();
      }
    }
  }

  Future<void> _showWelcomeDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '🍅 Welcome to Cherry Tomato!',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Would you like to take a quick tour of all the features?\n\nThis tutorial will show you:\n• Task Management\n• Pomodoro Timer\n• Calendar & Statistics\n• App Blocker\n• And more!',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Don\'t show again',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Start Tutorial',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() => _showTutorial = true);
    } else if (result == false) {
      await _skipTutorial();
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      final currentStepData = _steps[_currentStep];
      
      if (currentStepData.requiresNavigation && !_isNavigating) {
        // Navigate first, then show next step
        _isNavigating = true;
        setState(() => _showTutorial = false);
        
        // Check if we need to navigate back to home
        if (currentStepData.navigationTarget?.call() == null) {
          _navigateToHome();
        } else {
          _performNavigation(currentStepData.navigationTarget?.call());
        }
        
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _currentStep++;
              _showTutorial = true;
              _isNavigating = false;
            });
          }
        });
      } else {
        setState(() => _currentStep++);
      }
    } else {
      _completeTutorial();
    }
  }

  void _performNavigation(GlobalKey? targetKey) {
    if (targetKey?.currentContext == null) return;
    
    final element = targetKey!.currentContext as Element;
    _findAndTriggerTap(element);
  }

  void _navigateToHome() {
    // Navigate back to home screen
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  bool _findAndTriggerTap(Element element) {
    final widget = element.widget;
    
    if (widget is GestureDetector && widget.onTap != null) {
      widget.onTap!();
      return true;
    } else if (widget is InkWell && widget.onTap != null) {
      widget.onTap!();
      return true;
    } else if (widget is IconButton && widget.onPressed != null) {
      widget.onPressed!();
      return true;
    }
    
    bool found = false;
    element.visitChildElements((child) {
      if (!found) {
        found = _findAndTriggerTap(child);
      }
    });
    return found;
  }

  Future<void> _skipTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed_${widget.userId}', true);
    setState(() => _showTutorial = false);
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed_${widget.userId}', true);
    
    setState(() => _showTutorial = false);
    
    // Navigate back to home tab
    if (widget.onNavigateHome != null) {
      widget.onNavigateHome!();
    }
    
    // Also pop any navigation routes if needed
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    
    if (mounted) {
      // Small delay to ensure navigation completes
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        _showCompletionDialog();
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '🎉 Tutorial Complete!',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You\'re ready to boost your productivity with Cherry Tomato!\n\nRemember to enable the App Blocker for maximum focus!',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Let\'s Go!'),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButtonsPreview() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        children: [
          Text(
            'Mode Selection Buttons',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12.h),
          // Session indicator dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSessionDot(true),
              SizedBox(width: 8.w),
              _buildSessionDot(false),
              SizedBox(width: 8.w),
              _buildSessionDot(false),
              SizedBox(width: 8.w),
              _buildSessionDot(false),
            ],
          ),
          SizedBox(height: 16.h),
          // Mode button (like in your screenshot)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.green, width: 3),
            ),
            child: Text(
              'Classic Pomodoro',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Tap this button to change modes',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDot(bool isActive) {
    return Container(
      width: 12.w,
      height: 12.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? const Color(0xFFE53935) : Colors.grey[300],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showTutorial && _currentStep < _steps.length)
          SimpleTutorialOverlay(
            title: _steps[_currentStep].title,
            description: _steps[_currentStep].description,
            onNext: _nextStep,
            onSkip: _currentStep == 0 ? _skipTutorial : null,
            arrowTargetKey: _steps[_currentStep].hasArrow
                ? _steps[_currentStep].arrowTargetKey?.call()
                : null,
            showArrowAbove: _steps[_currentStep].showArrowAbove,
            centerCard: _steps[_currentStep].centerCard,
            imagePath: _steps[_currentStep].imagePath,
            customWidget: _steps[_currentStep].customWidget,
          ),
      ],
    );
  }
}

class TutorialStep {
  final String title;
  final String description;
  final bool hasArrow;
  final GlobalKey? Function()? arrowTargetKey;
  final bool showArrowAbove;
  final bool centerCard;
  final bool requiresNavigation;
  final GlobalKey? Function()? navigationTarget;
  final String? imagePath;
  final Widget? customWidget;

  TutorialStep({
    required this.title,
    required this.description,
    this.hasArrow = false,
    this.arrowTargetKey,
    this.showArrowAbove = false,
    this.centerCard = true,
    this.requiresNavigation = false,
    this.navigationTarget,
    this.imagePath,
    this.customWidget,
  });
}
