import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'homepage_app.dart'; // Task type
import 'package:tomatonator/services/session_service.dart';
import 'package:tomatonator/utilities/logger.dart';

/// Pomodoro / Short Break / Long Break single-page UI (UI-only logic)
/// Uses an in-memory timer (no persistence) and draws a circular progress
/// with a movable knob. Pure UI; no backend.
class PomodoroTimerPage extends StatefulWidget {
  final Task? task;
  const PomodoroTimerPage({super.key, this.task});

  @override
  State<PomodoroTimerPage> createState() => _PomodoroTimerPageState();
}

enum SessionType { pomodoro, shortBreak, longBreak }

class _PomodoroTimerPageState extends State<PomodoroTimerPage> {
  SessionType _current = SessionType.pomodoro;
  static const _durations = {
    SessionType.pomodoro: Duration(minutes: 25),
    SessionType.shortBreak: Duration(minutes: 5),
    SessionType.longBreak: Duration(minutes: 15),
  };

  Timer? _ticker;
  Duration _remaining = const Duration(minutes: 25);
  int _completedPomodoros = 0; // for cycle indicators (0-4)
  bool _isRunning = false;

  Duration get _total => _durations[_current]!;
  double get _progress => 1 - _remaining.inMilliseconds / _total.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _remaining = _total;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _switchSession(SessionType type) {
    setState(() {
      _current = type;
      _remaining = _durations[type]!;
      _stopTimer();
    });
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() => _isRunning = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remaining -= const Duration(seconds: 1);
        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          _stopTimer();
          _onComplete();
        }
      });
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;
    _ticker?.cancel();
    setState(() => _isRunning = false);
  }

  void _stopTimer() {
    _ticker?.cancel();
    _isRunning = false;
  }

  void _resetTimer() {
    _stopTimer();
    setState(() => _remaining = _total);
  }

  void _skipSession() {
    _stopTimer();
    _onComplete(forceSkip: true);
  }

  /// Called when the current session completes or is skipped.
  /// Records completed Pomodoro sessions locally and triggers sync.
  void _onComplete({bool forceSkip = false}) {
    if (_current == SessionType.pomodoro && !forceSkip) {
      _completedPomodoros++;
      // Save a completed Pomodoro session using the backend services.
      try {
        final durationMinutes = _durations[SessionType.pomodoro]!.inMinutes;
        // Record session (includes user_id if logged in) and attempt sync.
        SessionService.instance.recordCompletedSession(durationMinutes);
        // Optional user feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pomodoro completed and saved')), 
          );
        }
      } catch (e) {
        Logger.e('Failed to record session: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save session: $e')),
          );
        }
      }
      if (_completedPomodoros % 4 == 0) {
        _current = SessionType.longBreak;
      } else {
        _current = SessionType.shortBreak;
      }
    } else {
      _current = SessionType.pomodoro;
    }
    _remaining = _durations[_current]!;
    setState(() {});
  }

  String _format(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString();
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _accent => switch (_current) {
        SessionType.pomodoro => const Color(0xFFE53935),
        SessionType.shortBreak => const Color(0xFF2E7D32),
        SessionType.longBreak => const Color(0xFFFF9800),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title:
            const Text('Pomodoro Timer', style: TextStyle(color: Colors.black)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 4),
            Text('Currently Task',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 8),
            _buildTaskCard(),
            const SizedBox(height: 12),
            _buildSessionChips(), // Now a Row
            const SizedBox(height: 8),
            _buildCircularTimer(), // Smaller size
            const SizedBox(height: 16),
            _buildCycleRow(),
            const SizedBox(height: 4),
            _buildPresetBadge(),
            const SizedBox(height: 16),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard() {
    final t = widget.task;
    if (t == null) {
      return Container(); // Or a placeholder
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 48,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(value: t.isDone, onChanged: (_) {}),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(t.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _MiniMeta(icon: Icons.calendar_today, text: t.date),
                    _MiniMeta(icon: Icons.bolt, text: t.priority),
                    _MiniMeta(
                        icon: Icons.check_circle,
                        text:
                            'Subtask: ${t.completedSubtasks}/${t.totalSubtasks}'),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSessionChips() {
    const chipWidth = 100.0; // Slightly wider for all chips
    const chipPadding = EdgeInsets.symmetric(horizontal: 0, vertical: 2);
    final labels = {
      SessionType.pomodoro: 'Pomodoro',
      SessionType.shortBreak: 'Short Break',
      SessionType.longBreak: 'Long Break',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: SessionType.values.map((s) {
        final selected = s == _current;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: chipWidth,
            child: ChoiceChip(
              showCheckmark: false,
              label: Text(
                labels[s]!,
                textAlign: TextAlign.center,
              ),
              selected: selected,
              onSelected: (_) => _switchSession(s),
              selectedColor: _accent,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              backgroundColor: Colors.grey[300],
              padding: chipPadding,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCircularTimer() {
    return SizedBox(
      height: 260, // Increased from 220
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(builder: (context, constraints) {
            final stroke = 12.0;
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ProgressCirclePainter(
                      progress: _progress,
                      color: _accent,
                      strokeWidth: stroke,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    _format(_remaining),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCycleRow() {
    const total = 4;
    final filled = _completedPomodoros % total;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: active
                ? Image.asset(
                    'assets/timer/CHERRY TOMATO LOGO-01 1.png',
                    key: ValueKey('tomato_$i'),
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                  )
                : Container(
                    key: ValueKey('dot_$i'),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                  ),
          ),
        );
      }),
    );
  }

  Widget _buildPresetBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Classic Pomodoro',
        style: TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildControls() {
    final playIcon = _isRunning ? Icons.pause : Icons.play_arrow;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(icon: Icons.refresh, onTap: _resetTimer, enabled: true),
        const SizedBox(width: 30),
        GestureDetector(
          onTap: () => _isRunning ? _pauseTimer() : _startTimer(),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
              ],
            ),
            child: Icon(playIcon, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(width: 30),
        _circleButton(
            icon: Icons.skip_next, onTap: _skipSession, enabled: true),
      ],
    );
  }

  Widget _circleButton(
      {required IconData icon,
      required VoidCallback onTap,
      bool enabled = true}) {
    final disabled = !enabled;
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: disabled ? null : onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[400]!, width: 2),
            color: Colors.white,
          ),
          child: Icon(icon, color: Colors.grey[800], size: 30),
        ),
      ),
    );
  }
}

class _ProgressCirclePainter extends CustomPainter {
  final double progress; // 0 - 1
  final double strokeWidth;
  final Color color;
  _ProgressCirclePainter(
      {required this.progress, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final bgPaint = Paint()
      ..color = const Color(0xFFD1D3D4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    final sweep = 2 * math.pi * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _ProgressCirclePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

class _MiniMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.amber[800]),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
