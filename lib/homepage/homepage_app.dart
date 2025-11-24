import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'create_new_task.dart';
import 'calendar_page.dart';
import 'pomodoro_timer.dart';
import 'statistic_page.dart';
import 'profile.dart';
import 'session_history_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_page.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/session_service.dart';
import '../services/task_service.dart';
import '../services/database_service.dart';
import '../models/task.dart';
import '../models/session_type.dart';

const tomatoRed = Color(0xFFE53935);

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _selectedIndex = 0;
  final TaskService _taskService = TaskService.instance;
  List<Task> _tasks = [];
  final Set<int> _expandedTaskIndices = <int>{};

  @override
  void initState() {
    super.initState();
    _taskService.activeTasks.addListener(_handleTaskUpdates);
    _handleTaskUpdates();
    unawaited(_taskService.refreshActiveTasks());
  }

  @override
  void dispose() {
    _taskService.activeTasks.removeListener(_handleTaskUpdates);
    super.dispose();
  }

  void _handleTaskUpdates() {
    setState(() {
      _tasks = _taskService.activeTasks.value;
    });
  }

  String _formatDate(Task task) {
    if (task.dueAt == null) return '--/--/----';
    final dt = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  // Readable month-day for dropdown: e.g., "December 1"
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

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  // ✅ Proper pages list (ProfilePage now used directly)
  List<Widget> get _pages => [
        _buildHomeContent(), // 0 → Home
        CalendarPage(tasks: _tasks), // 1 → Calendar
        StatisticPage(tasks: _tasks), // 2 → Statistics Page with task data
        ProfilePage(onBack: () => _onItemTapped(0)), // 3 → Profile
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem("assets/Homepage/Home icon.png", 0),
              _buildNavItem("assets/Homepage/calendar icon.png", 1),
              const SizedBox(width: 40),
              _buildNavItem("assets/Homepage/stats icon.png", 2), // ✅ Stats
              _buildNavItem("assets/Homepage/profile icon.png", 3),
            ],
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        width: 90,
        height: 90,
        child: FloatingActionButton(
          backgroundColor: Colors.white,
          elevation: 3,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          splashColor: Colors.transparent,
          shape: const CircleBorder(),
          onPressed: () {
            // Cherry button intentionally disabled; timer accessible via task cards.
          },
          child: Image.asset(
            "assets/Homepage/pomodoro timer icon.png",
            fit: BoxFit.contain,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  /// HOME CONTENT
  Widget _buildHomeContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('assets/Homepage/tiny tomato.png',
                  width: 56, height: 56, fit: BoxFit.contain),
              ValueListenableBuilder(
                valueListenable: NotificationService.instance.notifications,
                builder: (context, list, _) {
                  final unread = list.where((n) => !n.read).length;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_none,
                          color: Colors.black,
                          size: 32,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationPage(),
                            ),
                          );
                        },
                      ),
                      if (unread > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935), // tomato red
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            constraints: const BoxConstraints(minWidth: 20),
                            child: Text(
                              unread.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String?>(
            valueListenable: ProfileService.instance.displayName,
            builder: (context, profileUsername, _) {
              // Fallbacks if profile username missing
              final user = AuthService.instance.currentUser;
              final username = profileUsername?.trim().isNotEmpty == true
                  ? profileUsername!.trim()
                  : (user?.username?.isNotEmpty == true
                      ? user!.username!
                      : (user?.email?.split('@').first ?? 'Cherry'));
              return Text('Hi there, $username',
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black));
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2))
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  Image.asset('assets/Homepage/goal.png', width: 56),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Welcome! Ready to start your first goal?',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tasks (${_tasks.length})',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              Row(children: [
                TextButton(
                  onPressed: () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateNewTaskPage(),
                      ),
                    );
                    if (created == true) {
                      unawaited(_taskService.refreshActiveTasks());
                    }
                  },
                  child: const Text('Add Task',
                      style: TextStyle(
                          color: tomatoRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SessionHistoryPage(),
                      ),
                    );
                  },
                  child: const Text('View History',
                      style: TextStyle(
                          color: tomatoRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, i) {
                final task = _tasks[i];
                final isExpandable = task.subtasks.isNotEmpty;
                final isExpanded = _expandedTaskIndices.contains(i);
                final Color priorityColor = _priorityColor(task.priority);

                return Column(
                  children: [
                    GestureDetector(
                      onTap: isExpandable
                          ? () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedTaskIndices.remove(i);
                                } else {
                                  _expandedTaskIndices.add(i);
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
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 2))
                          ],
                          color: Colors.white,
                          border: Border(
                            left: BorderSide(color: priorityColor, width: 10),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              Checkbox(
                                value: task.isDone,
                                onChanged: (val) {
                                  if (val == true && !task.isDone) {
                                    unawaited(SessionService.instance
                                        .recordTaskSnapshot(task));
                                    unawaited(
                                        _taskService.refreshActiveTasks());
                                  }
                                },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                        // No chevron — expansion still toggles on card tap
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today,
                                            color: Colors.amber, size: 16),
                                        const SizedBox(width: 4),
                                        Text(_formatDate(task),
                                            style: const TextStyle(
                                                color: Colors.amber)),
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
                                                  fontWeight:
                                                      FontWeight.w600)),
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
                                      builder: (context) =>
                                          PomodoroTimerPage(task: task),
                                    ),
                                  );
                                  if (result is Map &&
                                      (result['motivational'] == true)) {
                                    final msg = (result['message']
                                            as String?) ??
                                        'Keep going! Small steps lead to big wins.';
                                    _showMotivationDialog(msg);
                                  }
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
                                      final attention =
                                          _isSameDay(deadline, now) || deadline.isBefore(now);
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
                                                const SizedBox(height: 6),
                                                _NextReminderTicker(taskId: task.id, color: textColor.withOpacity(0.85)),
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
                                              await _taskService.updateSubtasks(
                                                  task, updated);
                                            },
                                            materialTapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          Expanded(
                                            child: Text(
                                              st.text.isNotEmpty
                                                  ? st.text
                                                  : 'Subtask ${idx + 1}',
                                              style: const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 14),
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String asset, int index) => GestureDetector(
        onTap: () => _onItemTapped(index),
        child: Image.asset(
          asset,
          width: 28,
          color: _selectedIndex == index ? tomatoRed : Colors.black54,
        ),
      );
}

class _NextReminderTicker extends StatefulWidget {
  final String taskId;
  final Color color;
  const _NextReminderTicker({required this.taskId, required this.color});
  @override
  State<_NextReminderTicker> createState() => _NextReminderTickerState();
}

class _NextReminderTickerState extends State<_NextReminderTicker> {
  DateTime? _next;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (_next == null || now.second % 5 == 0) {
        _load();
      }
      setState(() {});
    });
  }

  Future<void> _load() async {
    final rows = await DatabaseService.instance.getTaskReminders(widget.taskId);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    DateTime? best;
    for (final m in rows) {
      final ts = (m['reminder_time'] as num).toInt();
      if (ts >= nowMs) {
        final dt = DateTime.fromMillisecondsSinceEpoch(ts);
        if (best == null || dt.isBefore(best)) best = dt;
      }
    }
    if (mounted) setState(() => _next = best);
  }

  String _formatClock(DateTime dt) {
    final h24 = dt.hour;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    var h12 = h24 % 12;
    if (h12 == 0) h12 = 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h12:$m $ampm';
  }

  String _formatDiff(DateTime dt) {
    final now = DateTime.now();
    final d = dt.difference(now);
    if (d.isNegative) return 'due now';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.notifications_active, size: 16, color: Colors.black54),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            onTap: _load,
            child: Text(
              _next == null
                  ? 'No reminder scheduled'
                  : 'Next reminder ${_formatClock(_next!)} • ${_formatDiff(_next!)}',
              style: TextStyle(color: widget.color, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

extension on _HomepageState {
  void _showMotivationDialog(String message) {
    const messages = [
      "Remember, small steps lead to big wins!",
      "Even a tomato grows one drop at a time. Keep going next time!",
      "Rest is part of the journey, not the failure. You got this!",
      "One session ended, but your streak continues tomorrow!",
      "Keep your focus sharp — every effort counts!",
    ];

    final randomMsg = messages[math.Random().nextInt(messages.length)];

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Cherry Tomato',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secondaryAnim) {
        return PopScope(
          canPop: false,
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                  border: Border.all(color: Colors.redAccent.withOpacity(0.08)),
                ),
                child: Stack(
                  children: [
                    // Decorative faint cherry watermark
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: Opacity(
                        opacity: 0.06,
                        child: Image.asset(
                          'assets/sessiontoomato/minicherry.png',
                          width: 96,
                          height: 96,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset('assets/sessiontoomato/minicherry.png', width: 26, height: 26),
                              const SizedBox(width: 10),
                              Text(
                                "Cherry Tomato",
                                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            randomMsg,
                            style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                                  fontSize: 16,
                                  height: 1.45,
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Top-right circular close button
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: Colors.grey.shade200,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(ctx).pop(),
                          splashColor: Colors.black12,
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(Icons.close, size: 20, color: Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutQuad);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
}
}
