import 'package:flutter/material.dart';
import 'Homepage.dart'; // to use Task model

class CalendarPage extends StatefulWidget {
  final List<Task> tasks;

  const CalendarPage({super.key, required this.tasks});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selectedDate = DateTime.now();
  late PageController _pageController;
  int _currentWeekIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1000);
    _currentWeekIndex = 1000;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Task> get _tasksForDay {
    final selectedDay =
        "${_monthName(_selectedDate.month)} ${_selectedDate.day}, ${_selectedDate.year}";
    return widget.tasks.where((t) => t.date == selectedDay).toList();
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

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date); // if ISO format
      final mm = parsed.month.toString().padLeft(2, '0');
      final dd = parsed.day.toString().padLeft(2, '0');
      final yyyy = parsed.year.toString();
      return "$mm/$dd/$yyyy";
    } catch (e) {
      final parts = date.split(' ');
      if (parts.length == 3) {
        final months = {
          "January": "01",
          "February": "02",
          "March": "03",
          "April": "04",
          "May": "05",
          "June": "06",
          "July": "07",
          "August": "08",
          "September": "09",
          "October": "10",
          "November": "11",
          "December": "12",
        };
        final mm = months[parts[0]] ?? "01";
        final dd = parts[1].replaceAll(',', '').padLeft(2, '0');
        final yyyy = parts[2];
        return "$mm/$dd/$yyyy";
      }
      return date;
    }
  }

  void _goToPreviousWeek() {
    _pageController.previousPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _goToNextWeek() {
    _pageController.nextPage(
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Widget _buildTaskCard(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
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
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: task.isDone,
                    onChanged: (val) {
                      setState(() => task.isDone = val ?? false);
                    },
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
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationThickness: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(task.date),
                              style: const TextStyle(color: Colors.amber),
                            ),
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
                            const SizedBox(width: 12),
                            const Text(
                              "Subtask: 0/0",
                              style: TextStyle(color: Colors.green),
                            ),
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
  }

  Widget _buildWeek(DateTime weekStart) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final day = weekStart.add(Duration(days: i));
        final isSelected = day.day == _selectedDate.day &&
            day.month == _selectedDate.month &&
            day.year == _selectedDate.year;
        final hasTask = widget.tasks.any((t) =>
            t.date == "${_monthName(day.month)} ${day.day}, ${day.year}");

        return GestureDetector(
          onTap: () => setState(() => _selectedDate = day),
          child: Container(
            width: 45,
            height: 85,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.red : Colors.red[100],
              borderRadius: BorderRadius.circular(30),
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
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${day.day}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
                if (hasTask)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
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
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 18),
                onPressed: _goToPreviousWeek),
            Text("${_monthName(_selectedDate.month)} ${_selectedDate.year}",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
                onPressed: _goToNextWeek),
          ],
        ),
        const SizedBox(height: 8),

        // Rounded container for calendar + swipable weeks
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
            ],
          ),
          child: SizedBox(
            height: 100,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                final base =
                    DateTime.now().add(Duration(days: (index - 1000) * 7));
                setState(() {
                  _currentWeekIndex = index;
                  _selectedDate = base;
                });
              },
              itemBuilder: (context, index) {
                final base =
                    DateTime.now().add(Duration(days: (index - 1000) * 7));
                final startOfWeek =
                    base.subtract(Duration(days: base.weekday - 1));
                return _buildWeek(startOfWeek);
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Tasks (curved white panel)
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
                      itemBuilder: (context, i) {
                        final task = _tasksForDay[i];
                        return _buildTaskCard(task);
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
