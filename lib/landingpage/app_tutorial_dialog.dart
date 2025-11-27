import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

const tomatoRed = Color(0xFFE53935);

class AppTutorialDialog extends StatefulWidget {
  final String userId;
  
  const AppTutorialDialog({super.key, required this.userId});

  @override
  State<AppTutorialDialog> createState() => _AppTutorialDialogState();
}

class _AppTutorialDialogState extends State<AppTutorialDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _dontShowAgain = false;

  final List<TutorialStep> _steps = [
    TutorialStep(
      icon: Icons.add_task,
      title: 'Create & Manage Tasks',
      description:
          'Tap "Add Task" to create tasks with deadlines and priorities.\n\n'
          '💡 Long press any task card to edit or delete it.',
    ),
    TutorialStep(
      icon: Icons.play_circle_outline,
      title: 'Pomodoro Timer Modes',
      description:
          'Tap the play button (▶) on any task and choose:\n\n'
          '🍅 Classic: 25/5/15 mins\n'
          '📚 Long Study: 50/10/25 mins\n'
          '⚡ Quick Test: 15/5/10 mins\n'
          '⚙️ Custom: Set your own time',
    ),
    TutorialStep(
      icon: Icons.check_box,
      title: 'Track Subtasks',
      description:
          'Tap on a task card to expand and see subtasks.\n\n'
          'Check them off as you complete them!',
    ),
    TutorialStep(
      icon: Icons.block_outlined,
      title: 'Ad Blocker',
      description:
          'Enjoy a distraction-free experience!\n\n'
          'Cherry Tomato has no ads to interrupt your focus sessions.',
    ),
    TutorialStep(
      icon: Icons.bar_chart,
      title: 'View Your Stats',
      description:
          'Check the stats tab (📊) to see how much time you\'ve spent on the app and your productivity trends.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 60.h),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
          maxWidth: 340.w,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quick Guide',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600], size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            
            // Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 70.w,
                          height: 70.w,
                          decoration: BoxDecoration(
                            color: tomatoRed.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            step.icon,
                            size: 35.sp,
                            color: tomatoRed,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: tomatoRed,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          step.description,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Progress indicators
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) => Container(
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: _currentPage == index ? 18.w : 6.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? tomatoRed : Colors.grey[300],
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                ),
              ),
            ),
            
            // Don't show again checkbox
            if (_currentPage == _steps.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: _dontShowAgain,
                        onChanged: (value) {
                          setState(() => _dontShowAgain = value ?? false);
                        },
                        activeColor: tomatoRed,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Flexible(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _dontShowAgain = !_dontShowAgain);
                        },
                        child: Text(
                          "Don't show again",
                          style: TextStyle(
                            fontSize: 12.sp,
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
              padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 16.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      ),
                      child: Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14.sp,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 50),
                  if (_currentPage < _steps.length - 1)
                    ElevatedButton(
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tomatoRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 9.h,
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Next',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () async {
                        if (_dontShowAgain) {
                          final prefs = await SharedPreferences.getInstance();
                          final key = 'hide_app_tutorial_${widget.userId}';
                          await prefs.setBool(key, true);
                        }
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tomatoRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 9.h,
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Got it!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
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
  final String title;
  final String description;

  TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// Helper function to show the tutorial dialog
/// Shows every time unless the specific user checks "don't show again"
Future<void> showAppTutorial(BuildContext context, String userId) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'hide_app_tutorial_$userId';
  final hideAppTutorial = prefs.getBool(key) ?? false;
  
  // Only skip if this specific user explicitly opted out
  if (hideAppTutorial) return;
  
  if (context.mounted) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AppTutorialDialog(userId: userId),
    );
  }
}
