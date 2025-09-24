import 'package:flutter/material.dart';
import 'package:tomatonator/homepage.dart';

class CreateNewTaskPage extends StatefulWidget {
  final Task? task; // ✅ optional task for edit mode

  const CreateNewTaskPage({super.key, this.task});

  @override
  State<CreateNewTaskPage> createState() => _CreateNewTaskPageState();
}

class _CreateNewTaskPageState extends State<CreateNewTaskPage> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _date = TextEditingController();
  String? _priority;
  String _hour = "01";
  String _minute = "00";
  String _period = "AM";
  final List<Map<String, dynamic>> _subtasks = [];

  @override
  void initState() {
    super.initState();

    if (widget.task != null) {
      _title.text = widget.task!.title;
      _date.text = widget.task!.date;
      _priority = widget.task!.priority;

      final parts = widget.task!.time.split(" ");
      final hm = parts[0].split(":");
      _hour = hm[0];
      _minute = hm[1];
      _period = parts[1];

      for (int i = 0; i < widget.task!.totalSubtasks; i++) {
        _subtasks.add({
          "text": "Subtask ${i + 1}",
          "done": i < widget.task!.completedSubtasks,
        });
      }
    }
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
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          List<String> months = [
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
          setState(() {
            _date.text =
                "${months[picked.month - 1]} ${picked.day}, ${picked.year}";
          });
        }
      },
    );
  }

  Widget buildTimeSelector() {
    return Row(
      children: [
        DropdownButton<String>(
          value: _hour,
          items: List.generate(
            12,
            (i) => DropdownMenuItem(
              value: (i + 1).toString().padLeft(2, '0'),
              child: Text((i + 1).toString().padLeft(2, '0'),
                  style: const TextStyle(color: Colors.black)),
            ),
          ),
          onChanged: (val) => setState(() => _hour = val!),
        ),
        const Text(" : "),
        DropdownButton<String>(
          value: _minute,
          items: List.generate(
            60,
            (i) => DropdownMenuItem(
              value: i.toString().padLeft(2, '0'),
              child: Text(i.toString().padLeft(2, '0'),
                  style: const TextStyle(color: Colors.black)),
            ),
          ),
          onChanged: (val) => setState(() => _minute = val!),
        ),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _period,
          items: ["AM", "PM"]
              .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p, style: const TextStyle(color: Colors.black)),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _period = val!),
        ),
      ],
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
                  _subtasks.add({"text": "", "done": false});
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
        onPressed: () {
          final newTask = Task(
            title: _title.text,
            date: _date.text,
            priority: _priority ?? "Low",
            time: "$_hour:${_minute.toString().padLeft(2, '0')} $_period",
            completedSubtasks: _subtasks.where((s) => s["done"]).length,
            totalSubtasks: _subtasks.length,
            isDone: widget.task?.isDone ?? false,
          );
          Navigator.pop(context, newTask);
        },
        child: Text(
          widget.task == null ? "Create New Task" : "Save Changes",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}
