import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import 'package:tomatonator/services/app_usage_service.dart';

const tomatoRed = Color(0xFFE53935);

/// Weekly statistics page showing total app usage time per day in hours.
/// Fetches data from Supabase table `app_usage` and updates dynamically
/// whenever new usage data is recorded.
class StatisticPage extends StatelessWidget {
  final List<Task> tasks;
  const StatisticPage({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {

    // Build current week dates Sun → Sat
    final weekDates = _currentWeekDates();
    // Listen to usage minutes for the current week via AppUsageService
    final usageNotifier = AppUsageService.instance.weekUsageMinutes;

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
                  const Text(
                    "5",
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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

              FutureBuilder<List<Task>>(
                future: DatabaseService.instance.getTasks(
                  userId: AuthService.instance.currentUser?.id,
                ),
                builder: (context, snapshot) {
                  final list = snapshot.data ?? const <Task>[];
                  final pending = list.where((t) => t.isDone != true).length;
                  final completed = list.where((t) => t.isDone == true).length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBox(pending.toString(), "TASK", tomatoRed),
                      _buildStatBox(completed.toString(), "COMPLETED", Colors.green),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // 📊 Weekly usage chart (Sun → Sat), dynamic updates via ValueListenable
              ValueListenableBuilder<Map<DateTime, int>>(
                valueListenable: usageNotifier,
                builder: (context, usageMap, _) {
                  // Create an ordered list of minutes for the week
                  final minutesPerDay = weekDates
                      .map((d) => usageMap[d] ?? 0)
                      .toList(growable: false);
                  final maxMinutes =
                      (minutesPerDay.isEmpty) ? 0 : minutesPerDay.reduce((a, b) => a > b ? a : b);

                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 3))
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "For This Week",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 240,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List.generate(7, (i) {
                              final minutes = minutesPerDay[i];
                              final hours = (minutes / 60).toStringAsFixed(1);
                              final barHeight = maxMinutes > 0
                                  ? (minutes / (maxMinutes)) * 150
                                  : 2.0; // minimal height for visibility
                              final dayLabel = _dayLabel(weekDates[i]);
                              final barColor = _getDayColor(dayLabel);
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Hours label above the bar
                                  Text(
                                    hours,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    width: 26,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    dayLabel,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
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

  static Color _getDayColor(String day) {
    switch (day) {
      case "Sun":
        return Colors.redAccent;
      case "Mon":
        return Colors.orangeAccent;
      case "Tue":
        return Colors.yellowAccent;
      case "Wed":
        return Colors.greenAccent;
      case "Thu":
        return Colors.tealAccent;
      case "Fri":
        return Colors.blueAccent;
      case "Sat":
        return Colors.purpleAccent;
      default:
        return Colors.grey;
    }
  }

  /// Build list of dates for the current week (Sun → Sat)
  List<DateTime> _currentWeekDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysFromSunday = today.weekday % 7; // Sunday → 0
    final sunday = today.subtract(Duration(days: daysFromSunday));
    return List.generate(7, (i) {
      final d = sunday.add(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    });
  }

  /// Convert date to short day label used by color mapping
  String _dayLabel(DateTime d) {
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return labels[d.weekday % 7];
  }
}
