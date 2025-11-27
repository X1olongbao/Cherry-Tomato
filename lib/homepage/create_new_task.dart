import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../widgets/task_preset_dialog.dart';

class CreateNewTaskPage extends StatefulWidget {
  final Task? task; // ✅ optional task for edit mode

  const CreateNewTaskPage({super.key, this.task});

  @override
  State<CreateNewTaskPage> createState() => _CreateNewTaskPageState();
}

// Wrapper for preset-based task creation
class CreateNewTaskPageWithPreset extends StatefulWidget {
  final TaskPresetData presetData;
  final DateTime dueDateTime;

  const CreateNewTaskPageWithPreset({
    super.key,
    required this.presetData,
    required this.dueDateTime,
  });

  @override
  State<CreateNewTaskPageWithPreset> createState() => _CreateNewTaskPageWithPresetState();
}

class _CreateNewTaskPageWithPresetState extends State<CreateNewTaskPageWithPreset> {
  @override
  Widget build(BuildContext context) {
    return _CreateNewTaskPageInternal(
      presetData: widget.presetData,
      dueDateTime: widget.dueDateTime,
    );
  }
}

class _CreateNewTaskPageState extends State<CreateNewTaskPage> {
  @override
  Widget build(BuildContext context) {
    return _CreateNewTaskPageInternal(task: widget.task);
  }
}

class _CreateNewTaskPageInternal extends StatefulWidget {
  final Task? task;
  final TaskPresetData? presetData;
  final DateTime? dueDateTime;

  const _CreateNewTaskPageInternal({
    this.task,
    this.presetData,
    this.dueDateTime,
  });

  @override
  State<_CreateNewTaskPageInternal> createState() => _CreateNewTaskPageInternalState();
}

class _CreateNewTaskPageInternalState extends State<_CreateNewTaskPageInternal> {
  static const List<String> _months = [
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
  final TextEditingController _title = TextEditingController();
  final TextEditingController _date = TextEditingController();
  String? _priority;
  String _hour = "01";
  String _minute = "00";
  String _period = "AM";
  final List<Map<String, dynamic>> _subtasks = [];
  bool _timeSelected = false;

  bool get _isFormValid =>
      _title.text.trim().isNotEmpty &&
      _date.text.isNotEmpty &&
      _priority != null &&
      _timeSelected;

  TaskPriority _selectedPriority() {
    switch (_priority) {
      case 'High':
        return TaskPriority.high;
      case 'Medium':
        return TaskPriority.medium;
      case 'Low':
      default:
        return TaskPriority.low;
    }
  }

  DateTime? _selectedDueDateTime() {
    if (_date.text.isEmpty) return null;
    final cleaned = _date.text.replaceAll(',', '');
    final parts = cleaned.split(' ');
    if (parts.length < 3) return null;
    final monthIndex =
        _months.indexWhere((element) => element == parts[0]);
    if (monthIndex == -1) return null;
    final month = monthIndex + 1;
    final day = int.tryParse(parts[1]) ?? 1;
    final year = int.tryParse(parts[2]) ?? DateTime.now().year;
    int hour = int.tryParse(_hour) ?? 0;
    int minute = int.tryParse(_minute) ?? 0;
    if (_period == 'PM' && hour != 12) hour += 12;
    if (_period == 'AM' && hour == 12) hour = 0;
    return DateTime(year, month, day, hour, minute);
  }

  @override
  void initState() {
    super.initState();

    _title.addListener(() => setState(() {}));
    _date.addListener(() => setState(() {}));

    // Handle preset data
    if (widget.presetData != null && widget.dueDateTime != null) {
      _title.text = widget.presetData!.title;
      _setDateText(widget.dueDateTime!);
      _applyTime(widget.dueDateTime!);
      _priority = priorityToString(widget.presetData!.priority);
    }
    // Handle edit mode
    else if (widget.task != null) {
      final task = widget.task!;
      _title.text = task.title;
      if (task.dueAt != null) {
        final due = DateTime.fromMillisecondsSinceEpoch(task.dueAt!);
        _setDateText(due);
        _applyTime(due);
      }
      _priority = priorityToString(task.priority);
      _subtasks
        ..clear()
        ..addAll(task.subtasks
            .map((s) => {"id": s.id, "text": s.text, "done": s.done}));
    }
    // Default new task
    else {
      final now = DateTime.now();
      _setDateText(now);
      _applyTime(now);
    }
  }
  void _applyTime(DateTime source) {
    final hour = source.hour == 0
        ? 12
        : source.hour > 12
            ? source.hour - 12
            : source.hour;
    _hour = hour.toString().padLeft(2, '0');
    _minute = source.minute.toString().padLeft(2, '0');
    _period = source.hour >= 12 ? 'PM' : 'AM';
    _timeSelected = true;
  }

  void _setDateText(DateTime date) {
    _date.text = "${_months[date.month - 1]} ${date.day}, ${date.year}";
  }

  DateTime? _selectedDateOnly() {
    if (_date.text.isEmpty) return null;
    final cleaned = _date.text.replaceAll(',', '');
    final parts = cleaned.split(' ');
    if (parts.length < 3) return null;
    final monthIndex = _months.indexWhere((element) => element == parts[0]);
    if (monthIndex == -1) return null;
    final day = int.tryParse(parts[1]) ?? DateTime.now().day;
    final year = int.tryParse(parts[2]) ?? DateTime.now().year;
    return DateTime(year, monthIndex + 1, day);
  }


  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.task == null ? "Create New Task" : "Edit Task",
          style: const TextStyle(
            color: Colors.black,
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (widget.task != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                Navigator.pop(context, "delete"); // return delete signal
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildLabel("Title"),
              buildTextField(_title, "Task Title"),
              const SizedBox(height: 16),
              buildLabel("Date"),
              buildDatePickerField(),
              const SizedBox(height: 16),
              buildLabel("Start Time"),
              buildTimeSelector(),
              const SizedBox(height: 16),
              buildLabel("Select Priority"),
              buildPriorityDropdown(),
              const SizedBox(height: 16),
              buildSubtaskSection(),
              const SizedBox(height: 24),
              buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI Components ----------
  Widget buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[800],
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      style: const TextStyle(color: Colors.black, fontSize: 14),
    );
  }

  Widget buildDatePickerField() {
    return TextField(
      controller: _date,
      readOnly: true,
      decoration: InputDecoration(
        hintText: "Date",
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
        suffixIcon: const Icon(Icons.calendar_today, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      style: const TextStyle(color: Colors.black, fontSize: 14),
      onTap: () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final currentDate = _selectedDateOnly();
        final initialDate = (currentDate != null && !currentDate.isBefore(today))
            ? currentDate
            : today;
        final picked = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: today,
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          setState(() {
            _setDateText(picked);
            if (picked.isAtSameMomentAs(today)) {
              _applyTime(DateTime.now());
            }
          });
        }
      },
    );
  }

  Widget buildTimeSelector() {
    final display = _timeSelected
        ? "$_hour:${_minute.padLeft(2, '0')} $_period"
        : "";
    return TextField(
      readOnly: true,
      onTap: _showClockPicker,
      controller: TextEditingController(text: display),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        hintText: "Select Time",
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
        suffixIcon:
            const Icon(Icons.expand_more, size: 18, color: Colors.black54),
      ),
      style: const TextStyle(color: Colors.black, fontSize: 14),
    );
  }

  Future<void> _showClockPicker() async {
    int localHour = int.tryParse(_hour) ?? 1;
    int localMinute = int.tryParse(_minute) ?? 0;
    int localPeriodIdx = _period == 'AM' ? 0 : 1;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Time'),
        content: SizedBox(
          height: 150,
          child: Row(
            children: [
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  squeeze: 1.15,
                  useMagnifier: true,
                  magnification: 1.05,
                  looping: true,
                  scrollController: FixedExtentScrollController(
                      initialItem: (localHour.clamp(1, 12)) - 1),
                  onSelectedItemChanged: (i) => localHour = i + 1,
                  children: List.generate(
                    12,
                    (i) => Center(
                      child: Text(
                        (i + 1).toString().padLeft(2, '0'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  squeeze: 1.15,
                  useMagnifier: true,
                  magnification: 1.05,
                  looping: true,
                  scrollController: FixedExtentScrollController(
                      initialItem: localMinute.clamp(0, 59)),
                  onSelectedItemChanged: (i) => localMinute = i,
                  children: List.generate(
                    60,
                    (i) => Center(
                      child: Text(
                        i.toString().padLeft(2, '0'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  squeeze: 1.15,
                  useMagnifier: true,
                  magnification: 1.05,
                  looping: false,
                  scrollController: FixedExtentScrollController(
                      initialItem: localPeriodIdx),
                  onSelectedItemChanged: (i) => localPeriodIdx = i,
                  children: const [
                    Center(
                        child: Text('AM',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600))),
                    Center(
                        child: Text('PM',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final selectedDate = _selectedDateOnly() ?? DateTime.now();
              final normalizedSelected =
                  DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
              final now = DateTime.now();
              final normalizedNow = DateTime(now.year, now.month, now.day);
              int hour24 = localHour % 12;
              if (localPeriodIdx == 1) hour24 += 12;
              final candidate = DateTime(
                  normalizedSelected.year, normalizedSelected.month, normalizedSelected.day, hour24, localMinute);
              DateTime result = candidate;
              if (!normalizedSelected.isAfter(normalizedNow) && candidate.isBefore(now)) {
                result = now;
                _setDateText(now);
              }
              if (_date.text.isEmpty) {
                _setDateText(result);
              }
              setState(() {
                _applyTime(result);
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  Widget buildPriorityDropdown() {
    return DropdownButtonFormField<String>(
      value: _priority,
      items: ["High", "Medium", "Low"]
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text(p, style: const TextStyle(color: Colors.black)),
              ))
          .toList(),
      onChanged: (val) => setState(() => _priority = val),
      decoration: InputDecoration(
        hintText: "Select",
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }

  Widget buildSubtaskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            buildLabel("Subtask"),
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              onPressed: () {
                setState(() {
                  _subtasks.add({
                    "id":
                        'sub_${DateTime.now().millisecondsSinceEpoch}_${_subtasks.length}',
                    "text": "",
                    "done": false
                  });
                });
              },
            ),
          ],
        ),
        Column(
          children: _subtasks.asMap().entries.map((entry) {
            final index = entry.key;
            final subtask = entry.value;
            return Row(
              children: [
                Checkbox(
                  value: subtask["done"],
                  onChanged: (val) {
                    setState(() => _subtasks[index]["done"] = val);
                  },
                ),
                Expanded(
                  child: TextField(
                    onChanged: (val) => _subtasks[index]["text"] = val,
                    decoration: const InputDecoration(
                      hintText: "Subtask",
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE53935),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _isFormValid
            ? () async {
                final subtasks = _subtasks.asMap().entries.map((entry) {
                  final data = entry.value;
                  return TaskSubtask(
                    id: (data['id'] as String?) ??
                        'subtask_${entry.key}_${DateTime.now().millisecondsSinceEpoch}',
                    text: (data['text'] ?? '').toString(),
                    done: data['done'] == true,
                  );
                }).toList();
                final due = _selectedDueDateTime();
                if (widget.task == null) {
                  await TaskService.instance.createTask(
                    title: _title.text.trim(),
                    priority: _selectedPriority(),
                    createdAt: DateTime.now().millisecondsSinceEpoch,
                    dueAt: due?.millisecondsSinceEpoch,
                    clockTime:
                        "$_hour:${_minute.toString().padLeft(2, '0')} $_period",
                    subtasks: subtasks,
                  );
                } else {
                  await TaskService.instance.updateTaskDetails(
                    existing: widget.task!,
                    title: _title.text.trim(),
                    priority: _selectedPriority(),
                    due: due,
                    clockTime:
                        "$_hour:${_minute.toString().padLeft(2, '0')} $_period",
                    subtasks: subtasks,
                  );
                }
                if (mounted) {
                  Navigator.pop(context, true);
                }
              }
            : null,
        child: Text(
          widget.task == null ? "Create New Task" : "Save Changes",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}
