import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/session_service.dart';
import '../services/task_service.dart';
import 'pomodoro_timer.dart';

class CalendarPage extends StatefulWidget {
  final List<Task> tasks;

  const CalendarPage({super.key, this.tasks = const []});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selectedDate = DateTime.now();
  late ScrollController _dayScrollController;
  final Set<int> _expandedTaskIndices = <int>{};
  bool _hasCentered = false;

  double _dayWidth = 0;

  int get _daysInMonth =>
      DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);

  @override
  void initState() {
    super.initState();
    _dayScrollController = ScrollController();
  }

  @override
  void dispose() {
    _dayScrollController.dispose();
    super.dispose();
  }

  void _goToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelectedDay());
  }

  void _goToNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelectedDay());
  }

  void _centerSelectedDay() {
    if (_dayWidth == 0) return; // Wait for width to be calculated
    final idx = _selectedDate.day - 1;
    final screenWidth = MediaQuery.of(context).size.width;
    // Account for container padding (12 on each side = 24 total)
    final scrollableWidth = screenWidth - 24;
    // Each item has width _dayWidth + 8 (4 padding on each side)
    final itemWidth = _dayWidth + 8;
    final totalWidth = _daysInMonth * itemWidth;
    
    // Calculate the center position of the selected day
    final selectedDayCenter = (idx * itemWidth) + (_dayWidth / 2);
    // Calculate offset to center the selected day in the viewport
    double offset = selectedDayCenter - (scrollableWidth / 2);

    // Clamp the offset to valid scroll range
    if (offset < 0) offset = 0;
    if (offset > totalWidth - scrollableWidth) offset = totalWidth - scrollableWidth;
    if (totalWidth <= scrollableWidth) offset = 0;

    _dayScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => _CustomCalendarDialog(
        initialDate: _selectedDate,
        tasks: widget.tasks,
      ),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelectedDay());
    }
  }

  String _monthName(int month) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    return months[month - 1];
  }

  String _formatDate(Task task) {
    if (task.dueAt == null) return '--/--/----';
    final dt = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _formatMonthDay(Task task) {
    if (task.dueAt == null) return 'No due date';
    final dt = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    final month = months[dt.month - 1];
    return "$month ${dt.day}";
  }

  DateTime _parseDeadline(Task task) {
    if (task.dueAt != null) {
      return DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
    }
    return DateTime.now();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _relativeDeadlineText(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    final abs = diff.abs();
    if (abs.inDays >= 1) {
      final d = abs.inDays;
      return diff.isNegative
          ? "$d day${d > 1 ? 's' : ''} ago"
          : "in $d day${d > 1 ? 's' : ''}";
    } else if (abs.inHours >= 1) {
      final h = abs.inHours;
      return diff.isNegative
          ? "$h hour${h > 1 ? 's' : ''} ago"
          : "in $h hour${h > 1 ? 's' : ''}";
    } else {
      final m = abs.inMinutes;
      return diff.isNegative
          ? "$m min${m > 1 ? 's' : ''} ago"
          : "in $m min${m > 1 ? 's' : ''}";
    }
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
      default:
        return Colors.blue;
    }
  }

  IconData _priorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Icons.warning_amber_rounded;
      case TaskPriority.medium:
        return Icons.bolt;
      case TaskPriority.low:
      default:
        return Icons.arrow_downward_rounded;
    }
  }

  List<Task> get _tasksForDay {
    return widget.tasks.where((t) {
      if (t.dueAt == null) return false;
      final dt = DateTime.fromMillisecondsSinceEpoch(t.dueAt!);
      return dt.year == _selectedDate.year &&
          dt.month == _selectedDate.month &&
          dt.day == _selectedDate.day;
    }).toList();
  }

  Widget _buildTaskCard(Task task, int index) {
    final isExpandable = task.subtasks.isNotEmpty;
    final isExpanded = _expandedTaskIndices.contains(index);
    final Color priorityColor = _priorityColor(task.priority);

    return Column(
      children: [
        GestureDetector(
          onTap: isExpandable
              ? () {
                  setState(() {
                    if (isExpanded) {
                      _expandedTaskIndices.remove(index);
                    } else {
                      _expandedTaskIndices.add(index);
                    }
                  });
                }
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
              ],
              color: Colors.white,
              border: Border(
                left: BorderSide(color: priorityColor, width: 10),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: task.isDone,
                    onChanged: (val) {
                      if (val == true && !task.isDone) {
                        unawaited(SessionService.instance
                            .recordTaskSnapshot(task));
                        unawaited(TaskService.instance.refreshActiveTasks());
                      }
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.black,
                                  decoration: task.isDone
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  decorationThickness: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(_formatDate(task),
                                style: const TextStyle(color: Colors.amber)),
                            const SizedBox(width: 12),
                            Icon(
                              _priorityIcon(task.priority),
                              color: priorityColor,
                              size: 16,
                            ),
                            const Spacer(),
                            if (task.totalSubtasks > 0) ...[
                              Text(
                                  "Subtask: ${task.completedSubtasks}/${task.totalSubtasks}",
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PomodoroTimerPage(task: task),
                        ),
                      );
                    },
                    child: const Icon(Icons.play_arrow,
                        color: Colors.red, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: isExpanded
              ? Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 2))
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Builder(builder: (context) {
                          final deadline = _parseDeadline(task);
                          final now = DateTime.now();
                          final attention = _isSameDay(deadline, now) ||
                              deadline.isBefore(now);
                          final iconColor =
                              attention ? Colors.redAccent : Colors.amber;
                          final textColor =
                              attention ? Colors.redAccent : Colors.black87;
                          final rel = _relativeDeadlineText(deadline);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 16, color: iconColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Due ${_formatMonthDay(task)}, ${task.clockTime ?? task.formattedDueTime}',
                                      style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      rel,
                                      style: TextStyle(
                                        color: textColor.withOpacity(0.75),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 8),
                        // Subtasks list
                        ...task.subtasks.asMap().entries.map((e) {
                          final idx = e.key;
                          final st = e.value;
                          return Row(
                            children: [
                              Checkbox(
                                value: st.done,
                                onChanged: (val) async {
                                  final updated = task.subtasks
                                      .asMap()
                                      .entries
                                      .map((entry) => entry.key == idx
                                          ? entry.value.copyWith(
                                              done: val ?? false)
                                          : entry.value)
                                      .toList();
                                  await TaskService.instance
                                      .updateSubtasks(task, updated);
                                },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              Expanded(
                                child: Text(
                                  st.text.isNotEmpty
                                      ? st.text
                                      : 'Subtask ${idx + 1}',
                                  style: const TextStyle(
                                      color: Colors.black, fontSize: 14),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _dayWidth = (MediaQuery.of(context).size.width - 48) / 7;
    
    // Auto-center on current date on first build
    if (!_hasCentered && _dayWidth > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _centerSelectedDay();
          _hasCentered = true;
        }
      });
    }

    return Column(
      children: [
        const SizedBox(height: 12),

        // Month title and arrows
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: _goToPreviousDay,
            ),
            GestureDetector(
              onTap: _showDatePicker,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${_monthName(_selectedDate.month)} ${_selectedDate.day}, ${_selectedDate.year}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.calendar_month, size: 18, color: Colors.grey),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 18),
              onPressed: _goToNextDay,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Capsule Scroll Bar (days)
        Container(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
            ],
          ),
          child: SizedBox(
            height: 88,
            child: ListView.builder(
              controller: _dayScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _daysInMonth,
              itemBuilder: (context, i) {
                final day =
                    DateTime(_selectedDate.year, _selectedDate.month, i + 1);
                final isSelected = day.day == _selectedDate.day;
                final hasTask = widget.tasks.any((t) {
                  if (t.dueAt == null) return false;
                  final dt = DateTime.fromMillisecondsSinceEpoch(t.dueAt!);
                  return dt.year == day.year &&
                      dt.month == day.month &&
                      dt.day == day.day;
                });

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = day);
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _centerSelectedDay());
                    },
                    child: Container(
                      width: _dayWidth,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.red : Colors.red[100],
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            [
                              "Mon",
                              "Tue",
                              "Wed",
                              "Thu",
                              "Fri",
                              "Sat",
                              "Sun"
                            ][day.weekday - 1],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${day.day}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black,
                              fontSize: 15,
                            ),
                          ),
                          if (hasTask)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Tasks list panel
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _tasksForDay.isEmpty
                  ? const Center(child: Text("No tasks for this day."))
                  : ListView.builder(
                      itemCount: _tasksForDay.length,
                      itemBuilder: (context, i) =>
                          _buildTaskCard(_tasksForDay[i], i),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}


// Custom Calendar Dialog with Task Indicators
class _CustomCalendarDialog extends StatefulWidget {
  final DateTime initialDate;
  final List<Task> tasks;

  const _CustomCalendarDialog({
    required this.initialDate,
    required this.tasks,
  });

  @override
  State<_CustomCalendarDialog> createState() => _CustomCalendarDialogState();
}

class _CustomCalendarDialogState extends State<_CustomCalendarDialog> {
  late DateTime _displayedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
    _selectedDate = widget.initialDate;
  }

  bool _dateHasTasks(DateTime date) {
    return widget.tasks.any((task) {
      if (task.dueAt == null) return false;
      final taskDate = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
      return taskDate.year == date.year &&
          taskDate.month == date.month &&
          taskDate.day == date.day;
    });
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    });
  }

  String _monthName(int month) {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_displayedMonth.year, _displayedMonth.month);
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with month/year and navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousMonth,
                ),
                Text(
                  '${_monthName(_displayedMonth.month)} ${_displayedMonth.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Weekday headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((day) => SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            day,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            
            // Calendar grid
            ...List.generate((daysInMonth + firstWeekday + 6) ~/ 7, (weekIndex) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (dayIndex) {
                  final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 1;
                  
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const SizedBox(width: 40, height: 40);
                  }
                  
                  final date = DateTime(_displayedMonth.year, _displayedMonth.month, dayNumber);
                  final isSelected = date.year == _selectedDate.year &&
                      date.month == _selectedDate.month &&
                      date.day == _selectedDate.day;
                  final hasTasks = _dateHasTasks(date);
                  final isToday = date.year == DateTime.now().year &&
                      date.month == DateTime.now().month &&
                      date.day == DateTime.now().day;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDate = date);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE53935)
                            : isToday
                                ? const Color(0xFFE53935).withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday && !isSelected
                            ? Border.all(color: const Color(0xFFE53935), width: 1)
                            : null,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (hasTasks)
                            Positioned(
                              bottom: 4,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFFE53935),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            }),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
