import 'package:flutter/material.dart';
import 'create_new_task.dart';

const tomatoRed = Color(0xFFE53935);

class Task {
  final String title;
  final String date; // stored as "August 8, 2025"
  final String priority;
  final String time;
  final int completedSubtasks;
  final int totalSubtasks;
  bool isDone;

  Task({
    required this.title,
    required this.date,
    required this.priority,
    required this.time,
    required this.completedSubtasks,
    required this.totalSubtasks,
    this.isDone = false,
  });
}

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _selectedIndex = 0; // Track which icon is active
  final List<Task> _tasks = [];

  String _formatDate(String longDate) {
    final parts = longDate.replaceAll(',', '').split(' ');
    final monthNames = {
      "January": 1,
      "February": 2,
      "March": 3,
      "April": 4,
      "May": 5,
      "June": 6,
      "July": 7,
      "August": 8,
      "September": 9,
      "October": 10,
      "November": 11,
      "December": 12,
    };
    final month = monthNames[parts[0]] ?? 1;
    final day = parts[1];
    final year = parts[2];
    return "$month/$day/$year";
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('assets/Homepage/tiny tomato.png', width: 56, height: 56, fit: BoxFit.contain),
                  const Icon(Icons.notifications_none, color: Colors.black, size: 32),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Hi there, User', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    children: [
                      Image.asset('assets/Homepage/goal.png', width: 56),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text('Welcome! Ready to start your first goal?', style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tasks (${_tasks.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                  TextButton(
                    onPressed: () async {
                      final newTask = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateNewTaskPage()),
                      );
                      if (newTask != null && newTask is Task) {
                        setState(() => _tasks.add(newTask));
                      }
                    },
                    child: const Text('Add Task', style: TextStyle(color: tomatoRed, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _tasks.length,
                  itemBuilder: (context, i) {
                    final task = _tasks[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 80,
                            decoration: BoxDecoration(
                              color: task.priority == "High"
                                  ? Colors.red
                                  : task.priority == "Medium"
                                      ? Colors.orange
                                      : Colors.blue,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: task.isDone,
                                    onChanged: (val) => setState(() => task.isDone = val ?? false),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: Colors.black,
                                            decoration: task.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                            decorationThickness: 2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today, color: Colors.amber, size: 16),
                                            const SizedBox(width: 4),
                                            Text(_formatDate(task.date), style: const TextStyle(color: Colors.amber)),
                                            const SizedBox(width: 12),
                                            Icon(
                                              task.priority == "High"
                                                  ? Icons.warning_amber_rounded
                                                  : task.priority == "Medium"
                                                      ? Icons.bolt
                                                      : Icons.arrow_downward_rounded,
                                              color: task.priority == "High"
                                                  ? Colors.red
                                                  : task.priority == "Medium"
                                                      ? Colors.orange
                                                      : Colors.blue,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              task.priority,
                                              style: TextStyle(
                                                color: task.priority == "High"
                                                    ? Colors.red
                                                    : task.priority == "Medium"
                                                        ? Colors.orange
                                                        : Colors.blue,
                                              ),
                                            ),
                                            if (task.totalSubtasks > 0) ...[
                                              const SizedBox(width: 12),
                                              Text("Subtask: ${task.completedSubtasks}/${task.totalSubtasks}", style: const TextStyle(color: Colors.green)),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.play_arrow, color: Colors.red, size: 28),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
              _buildNavItem("assets/Homepage/stats icon.png", 2),
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
          shape: const CircleBorder(),
          onPressed: () {},
          child: Image.asset("assets/Homepage/pomodoro timer icon.png", fit: BoxFit.contain),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavItem(String asset, int index) => GestureDetector(
        onTap: () => _onItemTapped(index),
        child: Image.asset(asset, width: 28, color: _selectedIndex == index ? tomatoRed : Colors.black54),
      );
}
