import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/task.dart';

class TaskPresetDialog extends StatelessWidget {
  final Function(TaskPreset) onPresetSelected;

  const TaskPresetDialog({
    super.key,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Container(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: const Color(0xFFE53935),
                  size: 28.sp,
                ),
                SizedBox(width: 12.w),
                Text(
                  'Quick Task Templates',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Choose a preset to quickly create a task',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 20.h),

            // Preset cards
            _buildPresetCard(
              context,
              icon: Icons.school,
              iconColor: const Color(0xFF2196F3),
              title: 'Study Session',
              description: 'Focus on learning',
              duration: '2 hours',
              priority: 'High',
              onTap: () {
                Navigator.pop(context);
                onPresetSelected(TaskPreset.study);
              },
            ),
            SizedBox(height: 12.h),
            _buildPresetCard(
              context,
              icon: Icons.work,
              iconColor: const Color(0xFFFF9800),
              title: 'Work Task',
              description: 'Complete work assignment',
              duration: '1 day',
              priority: 'Medium',
              onTap: () {
                Navigator.pop(context);
                onPresetSelected(TaskPreset.work);
              },
            ),
            SizedBox(height: 12.h),
            _buildPresetCard(
              context,
              icon: Icons.fitness_center,
              iconColor: const Color(0xFF4CAF50),
              title: 'Exercise',
              description: 'Workout session',
              duration: '1 hour',
              priority: 'Medium',
              onTap: () {
                Navigator.pop(context);
                onPresetSelected(TaskPreset.exercise);
              },
            ),
            SizedBox(height: 12.h),
            _buildPresetCard(
              context,
              icon: Icons.book,
              iconColor: const Color(0xFF9C27B0),
              title: 'Reading',
              description: 'Read a book or article',
              duration: '1 hour',
              priority: 'Low',
              onTap: () {
                Navigator.pop(context);
                onPresetSelected(TaskPreset.reading);
              },
            ),
            SizedBox(height: 12.h),
            _buildPresetCard(
              context,
              icon: Icons.code,
              iconColor: const Color(0xFF00BCD4),
              title: 'Coding',
              description: 'Programming task',
              duration: '3 hours',
              priority: 'High',
              onTap: () {
                Navigator.pop(context);
                onPresetSelected(TaskPreset.coding);
              },
            ),
            SizedBox(height: 20.h),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
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

  Widget _buildPresetCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String duration,
    required String priority,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: iconColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 12.w),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 12.sp, color: Colors.grey[500]),
                      SizedBox(width: 4.w),
                      Text(
                        duration,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Icon(Icons.flag, size: 12.sp, color: _getPriorityColor(priority)),
                      SizedBox(width: 4.w),
                      Text(
                        priority,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: _getPriorityColor(priority),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              size: 16.sp,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return const Color(0xFFE53935);
      case 'Medium':
        return const Color(0xFFFF9800);
      case 'Low':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }
}

enum TaskPreset {
  study,
  work,
  exercise,
  reading,
  coding,
}

class TaskPresetData {
  final String title;
  final String description;
  final Duration dueIn;
  final TaskPriority priority;

  TaskPresetData({
    required this.title,
    required this.description,
    required this.dueIn,
    required this.priority,
  });

  static TaskPresetData fromPreset(TaskPreset preset) {
    switch (preset) {
      case TaskPreset.study:
        return TaskPresetData(
          title: 'Study Session',
          description: 'Focus on learning and understanding the material',
          dueIn: const Duration(hours: 2),
          priority: TaskPriority.high,
        );
      case TaskPreset.work:
        return TaskPresetData(
          title: 'Work Task',
          description: 'Complete work assignment',
          dueIn: const Duration(days: 1),
          priority: TaskPriority.medium,
        );
      case TaskPreset.exercise:
        return TaskPresetData(
          title: 'Exercise',
          description: 'Workout session',
          dueIn: const Duration(hours: 1),
          priority: TaskPriority.medium,
        );
      case TaskPreset.reading:
        return TaskPresetData(
          title: 'Reading',
          description: 'Read a book or article',
          dueIn: const Duration(hours: 1),
          priority: TaskPriority.low,
        );
      case TaskPreset.coding:
        return TaskPresetData(
          title: 'Coding Task',
          description: 'Programming and development work',
          dueIn: const Duration(hours: 3),
          priority: TaskPriority.high,
        );
    }
  }
}
