import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/task.dart';
import '../models/session_type.dart';
import 'package:tomatonator/services/session_service.dart';
import 'package:tomatonator/utilities/logger.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';

/// Pomodoro / Short Break / Long Break single-page UI (UI-only logic)
/// Uses an in-memory timer (no persistence) and draws a circular progress
/// with a movable knob. Pure UI; no backend.
class PomodoroTimerPage extends StatefulWidget {
  final Task? task;
  const PomodoroTimerPage({super.key, this.task});

  @override
  State<PomodoroTimerPage> createState() => _PomodoroTimerPageState();
}

enum PresetMode { classic, longStudy, quickTask, custom }

class _PomodoroTimerPageState extends State<PomodoroTimerPage> {
  SessionType _current = SessionType.pomodoro;
  Map<SessionType, Duration> _durations = {
    SessionType.pomodoro: const Duration(minutes: 25),
    SessionType.shortBreak: const Duration(minutes: 5),
    SessionType.longBreak: const Duration(minutes: 15),
  };
  PresetMode _presetMode = PresetMode.classic;
  // Focus check interval (15s for testing)
  static const Duration _focusCheckInterval = Duration(seconds: 15);

  Timer? _ticker;
  Duration _remaining = const Duration(minutes: 25);
  DateTime? _endAt; // target end time for robust countdown
  int _completedPomodoros = 0; // for cycle indicators (0-4)
  bool _isRunning = false;
  bool isSessionActive = false; // exposed state per request

  // Focus-check popup and alarm
  Timer? _focusCheckTimer;
  bool _isDialogShowing = false;
  final List<String> _focusMessages = const [
    'Still focused? Keep crushing those tasks!',
    'Quick check: Are you in the zone?',
    'Stay sharp! Focus still on point?',
    'Focus check: Yes or No?',
    'Eyes on the prize?'
  ];
  final math.Random _rand = math.Random();
  AudioPlayer? _alarmPlayer;
  bool _isAlarmPlaying = false;
  static const MethodChannel _blockerChannel = MethodChannel('com.example.tomatonator/installed_apps');

  // Humorous messages to display when a break ends
  final List<String> breakEndMessages = const [
    "Time to crush another session! Ready?",
    "Productivity never sleeps. Continue?",
    "Don't let the tomato spoil! Next round?",
    "Keep the streak alive! Next Pomodoro?",
    "Your brain asked for this break. Now, back to work?",
    "Pomodoro warriors never quit! Shall we continue?",
    "Your focus is like cheese… melt it? Just kidding, continue?",
    "The tomatoes are counting on you! Ready for another?",
    "Break's over! Let's go, champ!",
    "Another session awaits. Are you in?"
  ];

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
    _focusCheckTimer?.cancel();
    _stopAlarm();
    super.dispose();
  }

  void _switchSession(SessionType type) {
    setState(() {
      _current = type;
      _remaining = _durations[type]!;
      _stopTimer();
      _endAt = null;
    });
    if (type == SessionType.pomodoro) {
      unawaited(_startAppBlockerIfConfigured());
    } else {
      unawaited(_stopAppBlocker());
    }
  }

  void _startTimer() {
    if (_isRunning) return;
    // Set a target end time so ticks are resilient to frame drops/backgrounding
    _endAt ??= DateTime.now().add(_remaining);
    setState(() {
      _isRunning = true;
      isSessionActive = true;
    });
    // Warm up audio context after a user gesture to satisfy autoplay policies (web/mobile)
    unawaited(_warmupAudioContext());
    // Schedule periodic focus-checks only during Pomodoro sessions
    _scheduleFocusCheck();
    if (_current == SessionType.pomodoro) {
      unawaited(_startAppBlockerIfConfigured());
    } else {
      unawaited(_stopAppBlocker());
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        // Compute remaining by comparing to target end time
        final now = DateTime.now();
        final diff = _endAt!.difference(now);
        _remaining = diff.isNegative ? Duration.zero : diff;
        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          _stopTimer();
          unawaited(_onComplete());
        }
      });
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;
    _ticker?.cancel();
    setState(() => _isRunning = false);
    // Capture remaining at pause and clear end time
    _endAt = null;
    _focusCheckTimer?.cancel();
  }

  void _stopTimer() {
    _ticker?.cancel();
    _isRunning = false;
    _endAt = null;
    isSessionActive = false;
    _focusCheckTimer?.cancel();
    _stopAlarm();
    unawaited(_stopAppBlocker());
  }

  void _resetTimer() {
    _stopTimer();
    setState(() => _remaining = _total);
    _endAt = null;
  }

  void _skipSession() {
    // Only allow skip if the timer has started and is running
    if (!_isRunning) return;
    // Finish immediately and record as completed, but do NOT advance to next session
    setState(() => _remaining = Duration.zero);
    _stopTimer();
    unawaited(_onSkipComplete());
  }

  void _scheduleFocusCheck() {
    _focusCheckTimer?.cancel();
    if (_current != SessionType.pomodoro) return;
    _focusCheckTimer = Timer.periodic(_focusCheckInterval, (_) async {
      if (!mounted) return;
      if (_isRunning && _current == SessionType.pomodoro && !_isDialogShowing) {
        await _showFocusDialog();
      }
    });
  }

  /// Called when the current session completes or is skipped.
  /// Records completed sessions (Pomodoro, Short Break, Long Break) locally and triggers sync.
  Future<void> _onComplete({bool forceSkip = false}) async {
    // Record any finished session unless explicitly skipped
    if (!forceSkip) {
      try {
        final durationMinutes = _durations[_current]!.inMinutes;
        await SessionService.instance.recordCompletedSession(
          sessionType: _current,
          durationMinutes: durationMinutes,
          task: widget.task,
        );
        if (mounted) {
          final label = switch (_current) {
            SessionType.pomodoro => 'Pomodoro',
            SessionType.shortBreak => 'Short break',
            SessionType.longBreak => 'Long break',
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label completed and saved')),
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
    }
    // Advance flow according to requirements
    if (_current == SessionType.pomodoro) {
      // After Pomodoro: play 5-second alarm and automatically start break
      _completedPomodoros++;
      if (_completedPomodoros % 4 == 0) {
        _switchSession(SessionType.longBreak);
      } else {
        _switchSession(SessionType.shortBreak);
      }
      // Start break countdown automatically
      _playAlarmForFiveSeconds();
      _startTimer();
    } else if (_current == SessionType.shortBreak) {
      // After short break, alert user and prompt to continue
      _playAlarmForFiveSeconds();
      _showBreakEndDialog();
    } else if (_current == SessionType.longBreak) {
      // Long break completes the cycle automatically
      _handleCycleCompletion();
    }
  }

  /// Called when the user skips the current session.
  /// Saves the session locally like a normal completion, but stays on the same session type.
  Future<void> _onSkipComplete() async {
    // Save current session as skipped, then advance to next with feature flow
    final typeBefore = _current;
    try {
      final durationMinutes = _durations[typeBefore]!.inMinutes;
      await SessionService.instance.recordCompletedSession(
        sessionType: typeBefore,
        durationMinutes: durationMinutes,
        task: widget.task,
      );
      if (mounted) {
        final label = switch (typeBefore) {
          SessionType.pomodoro => 'Pomodoro',
          SessionType.shortBreak => 'Short break',
          SessionType.longBreak => 'Long break',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label skipped and saved')),
        );
      }
    } catch (e) {
      Logger.e('Failed to record skipped session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save session: $e')),
        );
      }
    }

    // Advance with feature behavior
    if (typeBefore == SessionType.pomodoro) {
      // Skip Pomodoro → go to appropriate break, play 5s alarm, start break
      _completedPomodoros++;
      if (_completedPomodoros % 4 == 0) {
        _switchSession(SessionType.longBreak);
      } else {
        _switchSession(SessionType.shortBreak);
      }
      _playAlarmForFiveSeconds();
      _startTimer();
    } else if (typeBefore == SessionType.shortBreak) {
      // Skip short break → same dialog as completion
      _showBreakEndDialog();
    } else {
      // Skipping the long break should end the cycle as well
      _handleCycleCompletion();
    }
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

  String _presetLabel(PresetMode m) => switch (m) {
        PresetMode.classic => 'Classic Pomodoro',
        PresetMode.longStudy => 'Long Study Mode',
        PresetMode.quickTask => 'Quick Task Mode',
        PresetMode.custom => 'Custom Mode',
      };

  void _applyPreset(PresetMode m) {
    switch (m) {
      case PresetMode.classic:
        _durations = {
          SessionType.pomodoro: const Duration(minutes: 25),
          SessionType.shortBreak: const Duration(minutes: 5),
          SessionType.longBreak: const Duration(minutes: 15),
        };
        break;
      case PresetMode.longStudy:
        _durations = {
          SessionType.pomodoro: const Duration(minutes: 50),
          SessionType.shortBreak: const Duration(minutes: 10),
          SessionType.longBreak: const Duration(minutes: 25),
        };
        break;
      case PresetMode.quickTask:
        _durations = {
          SessionType.pomodoro: const Duration(minutes: 15),
          SessionType.shortBreak: const Duration(minutes: 5),
          SessionType.longBreak: const Duration(minutes: 10),
        };
        break;
      case PresetMode.custom:
        // Preserve current custom values; no change here
        break;
    }
  }

  void _resetCycle({bool stopTimerFirst = true}) {
    if (stopTimerFirst) {
      _stopTimer();
    }
    if (!mounted) return;
    setState(() {
      _completedPomodoros = 0;
      _endAt = null;
      _current = SessionType.pomodoro;
      _remaining = _durations[_current]!;
    });
  }

  Future<void> _showPresetDialog() async {
    final isCustom = _presetMode == PresetMode.custom;
    final pomCtrl = TextEditingController(text: _durations[SessionType.pomodoro]!.inMinutes.toString());
    final shortCtrl = TextEditingController(text: _durations[SessionType.shortBreak]!.inMinutes.toString());
    final longCtrl = TextEditingController(text: _durations[SessionType.longBreak]!.inMinutes.toString());
    PresetMode selected = _presetMode;

    // Initial values for pickers
    final pomInit = _durations[SessionType.pomodoro]!.inMinutes;
    final shortInit = _durations[SessionType.shortBreak]!.inMinutes;
    final longInit = _durations[SessionType.longBreak]!.inMinutes;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        bool editable = isCustom;
        return StatefulBuilder(builder: (ctx, setLocal) {
          void updateFieldsFor(PresetMode mode) {
            selected = mode;
            editable = mode == PresetMode.custom;
            if (!editable) {
              switch (mode) {
                case PresetMode.classic:
                  pomCtrl.text = '25'; shortCtrl.text = '5'; longCtrl.text = '15'; break;
                case PresetMode.longStudy:
                  pomCtrl.text = '50'; shortCtrl.text = '10'; longCtrl.text = '25'; break;
                case PresetMode.quickTask:
                  pomCtrl.text = '15'; shortCtrl.text = '5'; longCtrl.text = '10'; break;
                case PresetMode.custom:
                  break;
              }
            }
            setLocal(() {});
          }

          InputDecoration fieldDec(String label) => InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixText: 'Min',
          );

          Widget numberField(TextEditingController c, {VoidCallback? onTap}) => SizedBox(
            width: 90,
            child: TextField(
              controller: c,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              readOnly: true,
              onTap: onTap,
              decoration: fieldDec('Min').copyWith(
                suffixIcon: (editable)
                    ? const Icon(Icons.expand_more, size: 18, color: Colors.black54)
                    : null,
              ),
            ),
          );

          Future<void> pickMinutes({required String title, required int initial, required int max, required void Function(int value) onPicked}) async {
            int localSelected = (initial.clamp(1, max));
            await showDialog<void>(
              context: ctx,
              barrierDismissible: true,
              builder: (dialogCtx) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  content: SizedBox(
                    height: 150,
                    child: CupertinoPicker(
                      itemExtent: 36,
                      squeeze: 1.15,
                      useMagnifier: true,
                      magnification: 1.05,
                      looping: true,
                      scrollController: FixedExtentScrollController(initialItem: localSelected - 1),
                      onSelectedItemChanged: (i) => localSelected = i + 1,
                      children: List.generate(max, (i) => Center(
                            child: Text('${i + 1}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          )),
                    ),
                  ),
                  actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        onPicked(localSelected);
                        Navigator.of(dialogCtx).pop();
                      },
                      child: const Text('Ok'),
                    ),
                  ],
                );
              },
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            title: const Text('Select Mode', style: TextStyle(fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<PresetMode>(
                  value: selected,
                  items: PresetMode.values.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(_presetLabel(m)),
                    );
                  }).toList(),
                  onChanged: (m) {
                    if (m == null) return;
                    updateFieldsFor(m);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Time', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                // Always show fields; in Custom mode, tapping opens a wheel picker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pomodoro'),
                    numberField(pomCtrl, onTap: editable
                        ? () async {
                            await pickMinutes(title: 'Pomodoro Minutes', initial: int.parse(pomCtrl.text), max: 60, onPicked: (v) {
                              pomCtrl.text = '$v';
                            });
                            setLocal(() {});
                          }
                        : null),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Short Break'),
                    numberField(shortCtrl, onTap: editable
                        ? () async {
                            await pickMinutes(title: 'Short Break Minutes', initial: int.parse(shortCtrl.text), max: 15, onPicked: (v) {
                              shortCtrl.text = '$v';
                            });
                            setLocal(() {});
                          }
                        : null),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Long Break'),
                    numberField(longCtrl, onTap: editable
                        ? () async {
                            await pickMinutes(title: 'Long Break Minutes', initial: int.parse(longCtrl.text), max: 30, onPicked: (v) {
                              longCtrl.text = '$v';
                            });
                            setLocal(() {});
                          }
                        : null),
                  ],
                ),
                
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    final p = int.tryParse(pomCtrl.text);
                    final s = int.tryParse(shortCtrl.text);
                    final l = int.tryParse(longCtrl.text);
                    if (p == null || p <= 0 || s == null || s <= 0 || l == null || l <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid minutes (> 0).')));
                      return;
                    }
                    setState(() {
                      _presetMode = selected;
                      if (selected != PresetMode.custom) {
                        _applyPreset(selected);
                      } else {
                        _durations = {
                          SessionType.pomodoro: Duration(minutes: p),
                          SessionType.shortBreak: Duration(minutes: s),
                          SessionType.longBreak: Duration(minutes: l),
                        };
                      }
                    });
                    _resetCycle();
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Ok'),
                ),
              ),
            ],
          );
        });
      },
    );
  }


  Future<void> _showFocusDialog() async {
    if (_isDialogShowing) return; // prevent multiple stacked dialogs
    _isDialogShowing = true;
    final message = _focusMessages[_rand.nextInt(_focusMessages.length)];
    // Start looping alarm
    await _startAlarmLoop();
    if (!mounted) {
      _isDialogShowing = false;
      await _stopAlarm();
      return;
    }
    // Rounded-corner dialog matching app style
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.timer, color: Colors.black87),
              const SizedBox(width: 8),
              Text('Focus Check', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () async {
                await _stopAlarm();
                // End the session and return to homepage
                _stopTimer();
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                if (mounted) {
                  // Go back to Homepage with motivational payload (to show popup)
                  final payload = {
                    'motivational': true,
                    'message': "That's okay! Let's reset and come back strong.",
                  };
                  Navigator.of(context).pop(payload);
                }
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _stopAlarm();
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
    _isDialogShowing = false;
  }

  Future<void> _handleCycleCompletion() async {
    await _stopAlarm();
    _stopTimer();
    _resetCycle(stopTimerFirst: false);
    await _showCycleCompleteDialog();
  }

  Future<void> _showCycleCompleteDialog() async {
    if (_isDialogShowing) return;
    _isDialogShowing = true;
    await _startAlarmLoop();
    if (!mounted) {
      _isDialogShowing = false;
      await _stopAlarm();
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.emoji_events, color: Colors.black87),
              SizedBox(width: 8),
              Text('Cycle Complete', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          content: const Text(
              'Amazing focus! You completed the full Pomodoro cycle. Ready to head back and plan the next one?'),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await _stopAlarm();
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                if (mounted) {
                  Navigator.of(context).pop({
                    'motivational': true,
                    'message':
                        'Cycle complete! Grab some water and celebrate this win 🎉',
                  });
                }
                _isDialogShowing = false;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Finish Session'),
            ),
          ],
        );
      },
    );
    _isDialogShowing = false;
  }

  Future<void> _startAlarmLoop() async {
    _alarmPlayer ??= AudioPlayer();
    try {
      // Ensure a clean state before starting loop
      await _alarmPlayer!.stop();
      await _alarmPlayer!.setVolume(1.0);
      await _alarmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer!.play(AssetSource('sounds/alarm.wav'));
      _isAlarmPlaying = true;
    } catch (e) {
      Logger.e('Failed to play alarm: $e');
    }
  }

  Future<void> _stopAlarm() async {
    try {
      await _alarmPlayer?.stop();
      _isAlarmPlaying = false;
    } catch (_) {}
  }

  /// Plays the alarm sound for 5 seconds, then stops.
  void _playAlarmForFiveSeconds() {
    unawaited(_startAlarmLoop());
    Future.delayed(const Duration(seconds: 5), () async {
      await _stopAlarm();
    });
  }

  Future<void> _warmupAudioContext() async {
    _alarmPlayer ??= AudioPlayer();
    try {
      // If alarm is currently playing, skip warmup to avoid interrupting audio.
      if (_isAlarmPlaying) return;
      // Prepare the asset and perform a brief muted play/pause to satisfy platforms requiring a user gesture
      await _alarmPlayer!.setReleaseMode(ReleaseMode.stop);
      await _alarmPlayer!.setVolume(0.0);
      await _alarmPlayer!.play(AssetSource('sounds/alarm.wav'));
      await Future.delayed(const Duration(milliseconds: 50));
      await _alarmPlayer!.pause();
      await _alarmPlayer!.setVolume(1.0);
    } catch (e) {
      Logger.e('Warmup audio failed: $e');
    }
  }

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
            const SizedBox(height: 12),
            _buildTestOverlayButton(),
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

  /// Shows a break-end dialog with humorous message and Yes/No actions.
  /// Yes: continue to next Pomodoro.
  /// No: stop cycle, return to Homepage and show a motivational popup.
  Future<void> _showBreakEndDialog() async {
    if (_isDialogShowing) return;
    _isDialogShowing = true;
    final message = breakEndMessages[_rand.nextInt(breakEndMessages.length)];
    if (!mounted) {
      _isDialogShowing = false;
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.celebration, color: Colors.black87),
              SizedBox(width: 8),
              Text('Break Finished', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () async {
                // Stop any audio and close dialog
                await _stopAlarm();
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                // Return to Homepage with motivational payload
                if (mounted) {
                  final payload = {
                    'motivational': true,
                    'message': 'Nice job taking a pause! You\'ve got this.'
                  };
                  Navigator.of(context).pop(payload);
                }
                _isDialogShowing = false;
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _stopAlarm();
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                // Continue with next Pomodoro
                _switchSession(SessionType.pomodoro);
                _startTimer();
                _isDialogShowing = false;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Yes'),
            ),
          ],
        );
      },
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
                    _MiniMeta(icon: Icons.calendar_today, text: t.formattedDueDate),
                    _MiniMeta(
                        icon: Icons.bolt,
                        text: priorityToString(t.priority)),
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
    final filled = _completedPomodoros.clamp(0, total);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: active
              ? Image.asset(
                  'assets/sessiontoomato/minicherry.png',
                  width: 22,
                  height: 22,
                  fit: BoxFit.contain,
                )
              : Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[300],
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                ),
        );
      }),
    );
  }

  Widget _buildPresetBadge() {
    return GestureDetector(
      onTap: _showPresetDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Text(
          _presetLabel(_presetMode),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
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
            icon: Icons.skip_next, onTap: _skipSession, enabled: _isRunning),
      ],
    );
  }

  Widget _buildTestOverlayButton() {
    return const SizedBox.shrink();
  }

  Future<void> _showBlockerOverlay() async {
    return;
  }

  Future<void> _startAppBlockerIfConfigured() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final pkgs = await _getBlockedPackages();
      if (pkgs.isEmpty) return;
      final proceed = await _confirmPermissionsIfNeeded();
      if (!proceed) return;
      await _blockerChannel.invokeMethod('startAppBlocker', {'packages': pkgs});
    } catch (_) {}
  }

  Future<void> _stopAppBlocker() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _blockerChannel.invokeMethod('stopAppBlocker');
    } catch (_) {}
  }

  Future<List<String>> _getBlockedPackages() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('blocked_packages') ?? <String>[];
  }

  Future<bool> _confirmPermissionsIfNeeded() async {
    try {
      final usageGranted = await _blockerChannel.invokeMethod<bool>('isUsageAccessGranted') ?? false;
      final overlayGranted = await _blockerChannel.invokeMethod<bool>('isOverlayPermissionGranted') ?? false;
      if (usageGranted && overlayGranted) return true;
      if (!mounted) return false;
      return await showDialog<bool>(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Permissions Required'),
                content: const Text('Enable Usage Access and "Draw over other apps" permissions to block selected apps.'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Grant')),
                ],
              );
            },
          ) ??
          false;
    } catch (_) {
      return true;
    }
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
