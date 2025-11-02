import 'package:flutter/material.dart';
import 'homepage_app.dart';

class CalendarPage extends StatefulWidget {
  final List<Task> tasks;

  const CalendarPage({super.key, this.tasks = const []});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selectedDate = DateTime.now();
  late ScrollController _dayScrollController;

  double _dayWidth = 0;

  int get _daysInMonth =>
      DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);

  @override
  void initState() {
    super.initState();
    _dayScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerSelectedDay());
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
    final idx = _selectedDate.day - 1;
    final screenWidth = MediaQuery.of(context).size.width;
    final totalWidth = _daysInMonth * _dayWidth;
    double offset = (idx * _dayWidth) - (screenWidth / 2 - _dayWidth / 2);

    if (offset < 0) offset = 0;
    if (offset > totalWidth - screenWidth) offset = totalWidth - screenWidth;
    if (totalWidth <= screenWidth) offset = 0;

    _dayScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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

  List<Task> get _tasksForDay {
    final selectedDay =
        "${_monthName(_selectedDate.month)} ${_selectedDate.day}, ${_selectedDate.year}";
    return widget.tasks.where((t) => t.date == selectedDay).toList();
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
                bottomLeft: Radius.circular(12),
              ),
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
                              task.date,
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
                            if (task.totalSubtasks > 0) ...[
                              const SizedBox(width: 12),
                              Text(
                                "Subtask: ${task.completedSubtasks}/${task.totalSubtasks}",
                                style: const TextStyle(color: Colors.green),
                              ),
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
  }

  @override
  Widget build(BuildContext context) {
    _dayWidth = (MediaQuery.of(context).size.width - 48) / 7;

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
            Text(
              "${_monthName(_selectedDate.month)} ${_selectedDate.day}, ${_selectedDate.year}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                final hasTask = widget.tasks.any((t) =>
                    t.date ==
                    "${_monthName(day.month)} ${day.day}, ${day.year}");

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
                          _buildTaskCard(_tasksForDay[i]),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
