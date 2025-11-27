import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

const tomatoRed = Color(0xFFE53935);

class AppTutorialDialog extends StatefulWidget {
  final String userId;
  
  const AppTutorialDialog({super.key, required this.userId});

  @override
  State<AppTutorialDialog> createState() => _AppTutorialDialogState();
}

class _AppTutorialDialogState extends State<AppTutorialDialog> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _dontShowAgain = false;
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  final List<TutorialStep> _steps = [
    TutorialStep(
      icon: Icons.waving_hand,
      iconColor: Color(0xFFFFB300),
      title: 'Welcome to Cherry Tomato! 🍅',
      subtitle: 'Your Productivity Companion',
      description: 'Let\'s take a hands-on tour! You\'ll actually use each feature as we guide you through the app.',
      gradient: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
      features: [],
    ),
    TutorialStep(
      icon: Icons.add_task,
      iconColor: Color(0xFF4CAF50),
      title: 'Task Management',
      subtitle: 'Organize Your Work',
      description: 'Create and manage your tasks efficiently:',
      gradient: [Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
      features: [
        '✓ Tap "Add Task" to create new tasks',
        '✓ Set deadlines and priorities (High/Medium/Low)',
        '✓ Add subtasks for complex projects',
        '✓ Long press any task to edit or delete',
        '✓ Check off tasks when completed',
        '✓ Expand tasks to view details',
      ],
    ),
    TutorialStep(
      icon: Icons.timer,
      iconColor: tomatoRed,
      title: 'Pomodoro Timer',
      subtitle: 'Focus Sessions',
      description: 'Choose from multiple timer modes:',
      gradient: [Color(0xFFFFCDD2), Color(0xFFEF9A9A)],
      features: [
        '🍅 Classic: 25 min work / 5 min break',
        '📚 Long Study: 50 min work / 10 min break',
        '⚡ Quick Task: 15 min work / 5 min break',
        '⚙️ Custom: Set your own times',
        '🔄 4-session cycle with long break',
        '🔔 Audio alerts when sessions end',
      ],
    ),
    TutorialStep(
      icon: Icons.calendar_today,
      iconColor: Color(0xFFFF6F00),
      title: 'Calendar View',
      subtitle: 'Plan Your Days',
      description: 'Stay organized with the calendar:',
      gradient: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
      features: [
        '📅 View tasks by date',
        '🔍 Visual indicators for busy days',
        '◀️ ▶️ Navigate between days',
        '📍 Auto-center on today',
        '✨ See all tasks for selected date',
      ],
    ),
    TutorialStep(
      icon: Icons.block,
      iconColor: Color(0xFF9C27B0),
      title: 'App Blocker',
      subtitle: 'Eliminate Distractions',
      description: 'Stay focused during work sessions:',
      gradient: [Color(0xFFE1BEE7), Color(0xFFCE93D8)],
      features: [
        '🚫 Block distracting apps',
        '📱 Scan and select apps to block',
        '🔒 Persistent overlay (can\'t bypass)',
        '⚙️ Enable in Privacy & Security',
        '✅ Auto-activates during Pomodoro',
        '🛡️ Permissions: Usage Access + Overlay',
      ],
    ),
    TutorialStep(
      icon: Icons.bar_chart,
      iconColor: Color(0xFF2196F3),
      title: 'Statistics & Analytics',
      subtitle: 'Track Your Progress',
      description: 'Monitor your productivity:',
      gradient: [Color(0xFFBBDEFB), Color(0xFF90CAF9)],
      features: [
        '🔥 Daily streak counter',
        '📊 Weekly screen time graph',
        '✅ Completed sessions count',
        '📋 Pending tasks overview',
        '📈 Productivity trends',
        '⏱️ Total focus time',
      ],
    ),
    TutorialStep(
      icon: Icons.notifications,
      iconColor: Color(0xFFFF5722),
      title: 'Notifications',
      subtitle: 'Stay Updated',
      description: 'Never miss important updates:',
      gradient: [Color(0xFFFFCCBC), Color(0xFFFFAB91)],
      features: [
        '🔔 Task reminders',
        '⏰ Session completion alerts',
        '📬 In-app notification center',
        '🔴 Unread badge counter',
        '⚙️ Toggle on/off in settings',
      ],
    ),
    TutorialStep(
      icon: Icons.person,
      iconColor: Color(0xFF00BCD4),
      title: 'Profile & Settings',
      subtitle: 'Personalize Your Experience',
      description: 'Customize your account:',
      gradient: [Color(0xFFB2EBF2), Color(0xFF80DEEA)],
      features: [
        '👤 Edit profile name',
        '📸 Upload profile picture',
        '🔐 Change password (with strength indicator)',
        '🔒 Privacy & security settings',
        '🚪 Logout option',
      ],
    ),
    TutorialStep(
      icon: Icons.history,
      iconColor: Color(0xFF795548),
      title: 'Session History',
      subtitle: 'Review Your Work',
      description: 'Access your past sessions:',
      gradient: [Color(0xFFD7CCC8), Color(0xFFBCAAA4)],
      features: [
        '📜 View all completed sessions',
        '🕐 Session timestamps',
        '📝 Associated task details',
        '☁️ Cloud sync with Supabase',
        '💾 Offline access available',
      ],
    ),
    TutorialStep(
      icon: Icons.sync,
      iconColor: Color(0xFF607D8B),
      title: 'Data Sync',
      subtitle: 'Always Up to Date',
      description: 'Your data is safe and synced:',
      gradient: [Color(0xFFCFD8DC), Color(0xFFB0BEC5)],
      features: [
        '☁️ Cloud backup via Supabase',
        '💾 Local SQLite storage',
        '🔄 Auto-sync when online',
        '📴 Offline mode support',
        '🔐 Secure authentication',
      ],
    ),
    TutorialStep(
      icon: Icons.rocket_launch,
      iconColor: tomatoRed,
      title: 'You\'re All Set! 🎉',
      subtitle: 'Ready to Boost Productivity',
      description: 'Start your journey to better focus and productivity. Remember: consistency is key!',
      gradient: [Color(0xFFFFCDD2), Color(0xFFEF9A9A)],
      features: [
        '💡 Tip: Start with small tasks',
        '🎯 Set realistic daily goals',
        '⏸️ Take breaks seriously',
        '📊 Review stats weekly',
        '🌟 Celebrate your progress!',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _rotateAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );
    
    _scaleController.forward();
    _rotateController.repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scaleController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _scaleController.reset();
    _scaleController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 400.w,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, 10.h),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 8.w, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'App Tutorial',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: tomatoRed,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600], size: 24.sp),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                    child: Column(
                      children: [
                        // Animated Icon
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            width: 100.w,
                            height: 100.w,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: step.gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: step.iconColor.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: Offset(0, 8.h),
                                ),
                              ],
                            ),
                            child: Icon(
                              step.icon,
                              size: 50.sp,
                              color: step.iconColor,
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),
                        
                        // Title
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 6.h),
                        
                        // Subtitle
                        Text(
                          step.subtitle,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: step.iconColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16.h),
                        
                        // Description
                        Text(
                          step.description,
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        // Features list
                        if (step.features.isNotEmpty) ...[
                          SizedBox(height: 16.h),
                          Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  step.gradient[0].withOpacity(0.1),
                                  step.gradient[1].withOpacity(0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: step.iconColor.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: step.features.map((feature) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4.h),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          feature,
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            color: Colors.black87,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Progress indicators
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: _currentPage == index ? 24.w : 8.w,
                    height: 8.h,
                    decoration: BoxDecoration(
                      color: _currentPage == index 
                          ? _steps[_currentPage].iconColor 
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
              ),
            ),
            
            // Don't show again checkbox (only on last page)
            if (_currentPage == _steps.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: Checkbox(
                        value: _dontShowAgain,
                        onChanged: (value) {
                          setState(() => _dontShowAgain = value ?? false);
                        },
                        activeColor: tomatoRed,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _dontShowAgain = !_dontShowAgain);
                        },
                        child: Text(
                          "Don't show this tutorial again",
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Navigation buttons
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  if (_currentPage > 0)
                    TextButton.icon(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: Icon(Icons.arrow_back, size: 18.sp, color: Colors.grey[600]),
                      label: Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      ),
                    )
                  else
                    const SizedBox(width: 80),
                  
                  // Next/Finish button
                  ElevatedButton(
                    onPressed: () async {
                      if (_currentPage < _steps.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        if (_dontShowAgain) {
                          final prefs = await SharedPreferences.getInstance();
                          final key = 'hide_app_tutorial_${widget.userId}';
                          await prefs.setBool(key, true);
                        }
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _steps[_currentPage].iconColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 12.h,
                      ),
                      elevation: 4,
                      shadowColor: _steps[_currentPage].iconColor.withOpacity(0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage < _steps.length - 1 ? 'Next' : 'Get Started!',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Icon(
                          _currentPage < _steps.length - 1 
                              ? Icons.arrow_forward 
                              : Icons.check_circle,
                          size: 18.sp,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TutorialStep {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradient;
  final List<String> features;

  TutorialStep({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradient,
    required this.features,
  });
}

/// Helper function to show the tutorial dialog
Future<void> showAppTutorial(BuildContext context, String userId) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'hide_app_tutorial_$userId';
  final hideAppTutorial = prefs.getBool(key) ?? false;
  
  if (hideAppTutorial) return;
  
  if (context.mounted) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AppTutorialDialog(userId: userId),
    );
  }
}
