import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/pomodoro_session.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';
import '../services/app_usage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const tomatoRed = Color(0xFFE53935);

/// Weekly statistics page showing total app usage time per day in hours.
/// Fetches data from Supabase table `app_usage` and updates dynamically
/// whenever new usage data is recorded.
class StatisticPage extends StatefulWidget {
  final List<Task> tasks;
  final VoidCallback onShowTasks;
  final VoidCallback onShowHistory;
  const StatisticPage({
    super.key,
    required this.tasks,
    required this.onShowTasks,
    required this.onShowHistory,
  });

  @override
  State<StatisticPage> createState() => _StatisticPageState();
}

class _StatisticPageState extends State<StatisticPage> {
  @override
  void initState() {
    super.initState();
    // Ensure latest screen-time data is pulled whenever statistics opens.
    AppUsageService.instance.refreshCurrentWeek();
  }

  Future<DateTime?> _fetchLastLogin() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return null;
      final row = await Supabase.instance.client
          .from('profiles')
          .select('last_login')
          .eq('id', userId)
          .maybeSingle();
      if (row is Map && row['last_login'] is String) {
        final s = (row['last_login'] as String).trim();
        if (s.isNotEmpty) {
          return DateTime.tryParse(s);
        }
      }
    } catch (_) {}
    return null;
  }

  Widget _buildWeeklyUsageChart() {
    return ValueListenableBuilder<Map<DateTime, int>>(
      valueListenable: AppUsageService.instance.weekUsageMinutes,
      builder: (context, data, _) {
        final entries = data.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No screen time data yet. Sign in to track usage.',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }
        final total = entries.fold<int>(0, (sum, e) => sum + (e.value));
        final avg = (total / entries.length).round();
        final maxVal = entries.map((e) => e.value).fold<int>(0, (m, v) => v > m ? v : m);
        final dayLabels = const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Screen Time (This Week)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (ctx, constraints) {
                final maxWidth = constraints.maxWidth - 100;
                return Column(
                  children: List.generate(entries.length, (i) {
                    final e = entries[i];
                    final idx = i % 7;
                    final mins = e.value;
                    final width = maxVal > 0 ? (mins / maxVal) * maxWidth : 0.0;
                    final hours = (mins ~/ 60);
                    final rem = mins % 60;
                    final label = dayLabels[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              label,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                          Expanded(
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECECEC),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                                Container(
                                  height: 18,
                                  width: width,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '${hours}h ${rem}m',
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Total: ${(total ~/ 60)}h ${total % 60}m',
                  style: const TextStyle(color: Colors.black87),
                ),
                const SizedBox(width: 16),
                Text(
                  'Avg/day: ${(avg ~/ 60)}h ${avg % 60}m',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeeklyUsageGraph() {
    final weekDates = _currentWeekDates();
    return ValueListenableBuilder<Map<DateTime, int>>(
      valueListenable: AppUsageService.instance.weekUsageMinutes,
      builder: (context, usageMap, _) {
        final minutesPerDay = weekDates.map((d) => usageMap[d] ?? 0).toList(growable: false);
        final maxMinutes = minutesPerDay.isEmpty ? 0 : minutesPerDay.reduce((a, b) => a > b ? a : b);
        final total = minutesPerDay.fold<int>(0, (sum, m) => sum + m);
        final avg = minutesPerDay.isEmpty ? 0 : (total / minutesPerDay.length).round();
        // Always render graph even if all zeros
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Screen Time (This Week)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: CustomPaint(
                painter: _BarChartPainter(minutesPerDay: minutesPerDay, maxMinutes: maxMinutes, barColor: tomatoRed),
                child: Container(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Total: ${(total ~/ 60)}h ${total % 60}m', style: const TextStyle(color: Colors.black87)),
                const SizedBox(width: 16),
                Text('Avg/day: ${(avg ~/ 60)}h ${avg % 60}m', style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ],
        );
      },
    );
  }

  List<DateTime> _currentWeekDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysFromSunday = today.weekday % 7;
    final sunday = today.subtract(Duration(days: daysFromSunday));
    return List.generate(7, (i) {
      final d = sunday.add(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    });
  }

  String _dayLabel(DateTime d) {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final idx = d.weekday % 7;
    return labels[idx];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Statistics",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "You have a streak going for",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 🍅 Replaced the circle with image
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3))
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/stats/CHERRY TOMATO LOGO-01 2.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  FutureBuilder<List<dynamic>>(
                    future: Future.wait([
                      SessionService.instance.mergedSessionsForCurrentUser(),
                      _fetchLastLogin(),
                    ]),
                    builder: (context, snapshot) {
                      int streak = 0;
                      final sessions = (snapshot.data != null && snapshot.data!.isNotEmpty)
                          ? (snapshot.data![0] as List<PomodoroSession>)
                          : const <PomodoroSession>[];
                      final lastLogin = (snapshot.data != null && snapshot.data!.length > 1)
                          ? (snapshot.data![1] as DateTime?)
                          : null;
                      if (lastLogin != null) {
                        final diff = DateTime.now().toUtc().difference(lastLogin.toUtc());
                        if (diff.inHours >= 48) {
                          return const Text(
                            '0',
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }
                      }
                      if (sessions.isNotEmpty) {
                        final dates = <DateTime>{};
                        for (final s in sessions) {
                          final dt = DateTime.fromMillisecondsSinceEpoch(s.completedAt);
                          final d = DateTime(dt.year, dt.month, dt.day);
                          dates.add(d);
                        }
                        DateTime today = DateTime.now();
                        DateTime cur = DateTime(today.year, today.month, today.day);
                        // If no activity today, allow starting from yesterday
                        if (!dates.contains(cur)) {
                          final y = cur.subtract(const Duration(days: 1));
                          if (dates.contains(y)) {
                            cur = y;
                          } else {
                            cur = DateTime(1970);
                          }
                        }
                        while (dates.contains(cur)) {
                          streak++;
                          cur = cur.subtract(const Duration(days: 1));
                        }
                      }
                      return Text(
                        streak.toString(),
                        style: const TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // 🧭 Pomodoro Overview
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Pomodoro Overview",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              FutureBuilder<List<dynamic>>(
                future: Future.wait([
                  DatabaseService.instance.getTasks(
                    userId: AuthService.instance.currentUser?.id,
                  ),
                  SessionService.instance.mergedSessionsForCurrentUser(),
                ]),
                builder: (context, snapshot) {
                  final tasks = snapshot.data != null && snapshot.data!.isNotEmpty
                      ? (snapshot.data![0] as List<Task>)
                      : const <Task>[];
                  final finished = snapshot.data != null && snapshot.data!.length > 1
                      ? (snapshot.data![1] as List<PomodoroSession>)
                      : const <PomodoroSession>[];
                  final pending = tasks.where((t) => t.isDone != true).length;
                  final completed = finished.length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: widget.onShowTasks,
                        child: _buildStatBox(pending.toString(), "TASK", tomatoRed),
                      ),
                      GestureDetector(
                        onTap: widget.onShowHistory,
                        child: _buildStatBox(completed.toString(), "COMPLETED", Colors.green),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              _buildWeeklyUsageGraph(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildStatBox(String number, String label, Color color) {
    return Container(
      width: 140,
      height: 100,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 36,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  
}

class _BarChartPainter extends CustomPainter {
  final List<int> minutesPerDay;
  final int maxMinutes;
  final Color barColor;
  _BarChartPainter({required this.minutesPerDay, required this.maxMinutes, required this.barColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paddingLeft = 12.0;
    final paddingRight = 20.0;
    final paddingTop = 8.0;
    final paddingBottom = 36.0; // extra bottom space for day labels
    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;
    final origin = Offset(paddingLeft, size.height - paddingBottom);

    final axisPaint = Paint()..color = Colors.black12..strokeWidth = 1.5;
    final gridPaint = Paint()..color = const Color(0xFFECECEC)..strokeWidth = 1;
    final barPaint = Paint()..color = barColor..style = PaintingStyle.fill;

    canvas.drawLine(origin, Offset(origin.dx + chartWidth, origin.dy), axisPaint);
    canvas.drawLine(origin, Offset(origin.dx, origin.dy - chartHeight), axisPaint);

    for (int i = 1; i <= 3; i++) {
      final y = origin.dy - chartHeight * (i / 4);
      canvas.drawLine(Offset(origin.dx, y), Offset(origin.dx + chartWidth, y), gridPaint);
    }

    final count = minutesPerDay.isEmpty ? 7 : minutesPerDay.length;
    final groupWidth = chartWidth / count;
    final barWidth = groupWidth * 0.7;

    const dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final labelStyle = const TextStyle(color: Colors.black54, fontSize: 11);

    final safeMax = maxMinutes <= 0 ? 1 : maxMinutes;
    for (int i = 0; i < count; i++) {
      final mins = minutesPerDay.isEmpty ? 0 : minutesPerDay[i];
      final h = chartHeight * (mins / safeMax);
      final cx = origin.dx + groupWidth * (i + 0.5);
      final left = cx - barWidth / 2;
      final top = origin.dy - h;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, barWidth, h), const Radius.circular(6));
      canvas.drawRRect(rect, barPaint);

      final hours = mins ~/ 60;
      final rem = mins % 60;
      final textSpan = TextSpan(text: '${hours}h ${rem}m', style: const TextStyle(color: Colors.black87, fontSize: 10));
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout(maxWidth: groupWidth);
      final tx = cx - tp.width / 2;
      final ty = top - 12;
      tp.paint(canvas, Offset(tx, ty));

      final dLabel = dayLabels[i % 7];
      final dl = TextPainter(text: TextSpan(text: dLabel, style: labelStyle), textDirection: TextDirection.ltr);
      dl.layout(maxWidth: groupWidth);
      final dx = cx - dl.width / 2;
      final dy = origin.dy + 4;
      dl.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.minutesPerDay != minutesPerDay ||
        oldDelegate.maxMinutes != maxMinutes ||
        oldDelegate.barColor != barColor;
  }
}
