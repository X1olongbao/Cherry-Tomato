import 'package:flutter/material.dart';
import 'homepage_app.dart';

const tomatoRed = Color(0xFFE53935);

class StatisticPage extends StatelessWidget {
  final List<Task> tasks;
  const StatisticPage({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final int totalTasks = tasks.length;
    final int completedTasks =
        tasks.where((t) => t.isDone == true).length;

    final weeklyData = {
      "Sun": 14,
      "Mon": 18,
      "Tue": 15,
      "Wed": 10,
      "Thu": 8,
      "Fri": 17,
      "Sat": 14,
    };
    final maxValue = weeklyData.values.reduce((a, b) => a > b ? a : b);

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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatBox(totalTasks.toString(), "TASK", tomatoRed),
                  _buildStatBox(
                      completedTasks.toString(), "COMPLETED", Colors.green),
                ],
              ),
              const SizedBox(height: 32),

              // 📊 Weekly chart
              Container(
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
                      height: 220,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: weeklyData.entries.map((entry) {
                          final barHeight = (entry.value / maxValue) * 160;
                          final barColor = _getDayColor(entry.key);
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: 24,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                entry.key,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
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
}
