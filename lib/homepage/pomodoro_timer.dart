import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/task.dart';
import '../models/session_type.dart';
import 'package:tomatonator/services/session_service.dart';
import 'package:tomatonator/services/task_service.dart';
import 'package:tomatonator/services/system_notification_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
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

enum PresetMode { classic, longStudy, quickTask, custom }

class _PersistentTimerState {
  SessionType current = SessionType.pomodoro;
  Map<SessionType, Duration> durations = {
    SessionType.pomodoro: const Duration(minutes: 25),
    SessionType.shortBreak: const Duration(minutes: 5),
    SessionType.longBreak: const Duration(minutes: 15),
  };
  PresetMode presetMode = PresetMode.classic;
  Duration remaining = const Duration(minutes: 25);
  DateTime? endAt;
  int completedPomodoros = 0;
  bool isRunning = false;
  bool isSessionActive = false;
  bool oneMinuteAlertSent = false;
  bool tenSecondAlertSent = false;
  bool hasData = false;
}

final _pomodoroTimerCache = _PersistentTimerState();

class _PomodoroTimerPageState extends State<PomodoroTimerPage> {
  SessionType _current = SessionType.pomodoro;
  Map<SessionType, Duration> _durations = {
    SessionType.pomodoro: const Duration(minutes: 25),
    SessionType.shortBreak: const Duration(minutes: 5),
    SessionType.longBreak: const Duration(minutes: 15),
  };
  PresetMode _presetMode = PresetMode.classic;
  // Focus check interval: every 7 minutes
  static const Duration _focusCheckInterval = Duration(minutes: 7);

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
  bool _oneMinuteAlertSent = false;
  bool _tenSecondAlertSent = false;
  static const MethodChannel _blockerChannel = MethodChannel('com.example.tomatonator/installed_apps');

  Duration get _total => _durations[_current]!;
  double get _progress => 1 - _remaining.inMilliseconds / _total.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _restoreTimerState();
  }

  @override
  void dispose() {
    _persistTimerState();
    _ticker?.cancel();
    _focusCheckTimer?.cancel();
    _stopAlarm();
    if (!_isRunning || _current != SessionType.pomodoro) {
      unawaited(_stopAppBlocker());
    }
    super.dispose();
  }

  void _restoreTimerState() {
    if (!_pomodoroTimerCache.hasData) {
      _remaining = _total;
      _resetPreAlerts();
      return;
    }
    _current = _pomodoroTimerCache.current;
    _durations = Map<SessionType, Duration>.from(_pomodoroTimerCache.durations);
    _presetMode = _pomodoroTimerCache.presetMode;
    _remaining = _pomodoroTimerCache.remaining;
    _endAt = _pomodoroTimerCache.endAt;
    _completedPomodoros = _pomodoroTimerCache.completedPomodoros;
    _isRunning = _pomodoroTimerCache.isRunning;
    isSessionActive = _pomodoroTimerCache.isSessionActive;
    _oneMinuteAlertSent = _pomodoroTimerCache.oneMinuteAlertSent;
    _tenSecondAlertSent = _pomodoroTimerCache.tenSecondAlertSent;
    _syncRemainingWithEnd();
    if (_isRunning && _endAt != null && _remaining > Duration.zero) {
      _scheduleFocusCheck();
      _startTicker();
    }
  }

  void _syncRemainingWithEnd() {
    if (_endAt == null) return;
    final diff = _endAt!.difference(DateTime.now());
    if (diff.isNegative) {
      _remaining = Duration.zero;
      _oneMinuteAlertSent = true;
      _tenSecondAlertSent = true;
      if (_isRunning) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _stopTimer();
          unawaited(_onComplete());
        });
      }
    } else {
      _remaining = diff;
      if (_remaining <= const Duration(minutes: 1)) {
        _oneMinuteAlertSent = true;
      }
      if (_remaining <= const Duration(seconds: 10)) {
        _tenSecondAlertSent = true;
      }
    }
  }

  void _persistTimerState() {
    _pomodoroTimerCache
      ..current = _current
      ..durations = Map<SessionType, Duration>.from(_durations)
      ..presetMode = _presetMode
      ..remaining = _remaining
      ..endAt = _endAt
      ..completedPomodoros = _completedPomodoros
      ..isRunning = _isRunning
      ..isSessionActive = isSessionActive
      ..oneMinuteAlertSent = _oneMinuteAlertSent
      ..tenSecondAlertSent = _tenSecondAlertSent
      ..hasData = true;
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _endAt == null) return;
      setState(() {
        final diff = _endAt!.difference(DateTime.now());
        _remaining = diff.isNegative ? Duration.zero : diff;
        _maybeTriggerPreAlerts();
        if (_remaining <= Duration.zero) {
          _remaining = Duration.zero;
          _stopTimer();
          unawaited(_onComplete());
        }
      });
    });
  }

  void _switchSession(SessionType type) {
    setState(() {
      _current = type;
      _remaining = _durations[type]!;
      _stopTimer();
      _endAt = null;
      _resetPreAlerts();
    });
    _persistTimerState();
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
    _persistTimerState();
    // Warm up audio context after a user gesture to satisfy autoplay policies (web/mobile)
    unawaited(_warmupAudioContext());
    // Schedule periodic focus-checks only during Pomodoro sessions
    _scheduleFocusCheck();
    if (_current == SessionType.pomodoro) {
      unawaited(_startAppBlockerIfConfigured());
      // Notify Pomodoro start
      unawaited(SystemNotificationService.instance.notifyPomodoroStart(
        taskName: widget.task?.title,
      ));
    } else {
      unawaited(_stopAppBlocker());
      // Notify break start
      final breakType = _current == SessionType.shortBreak ? 'Short' : 'Long';
      final durationMinutes = _durations[_current]!.inMinutes;
      unawaited(SystemNotificationService.instance.notifyBreakStart(
        breakType: breakType,
        durationMinutes: durationMinutes,
      ));
    }
    _startTicker();
  }

  void _stopTimer() {
    _ticker?.cancel();
    _isRunning = false;
    _endAt = null;
    isSessionActive = false;
    _focusCheckTimer?.cancel();
    _stopAlarm();
    unawaited(_stopAppBlocker());
    _persistTimerState();
  }

  void _resetTimer() {
    _stopTimer();
    setState(() => _remaining = _total);
    _endAt = null;
    _resetPreAlerts();
    _persistTimerState();
  }

  void _resetPreAlerts() {
    _oneMinuteAlertSent = false;
    _tenSecondAlertSent = false;
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

  void _maybeTriggerPreAlerts() {
    if (_remaining <= Duration.zero) return;
    if (!_oneMinuteAlertSent && _remaining <= const Duration(minutes: 1)) {
      _oneMinuteAlertSent = true;
      _playTimedAlarm(const Duration(seconds: 2));
      Logger.i('Pre-alert: 1 minute remaining');
      _persistTimerState();
    }
    if (!_tenSecondAlertSent && _remaining <= const Duration(seconds: 10)) {
      _tenSecondAlertSent = true;
      _playTimedAlarm(const Duration(seconds: 2));
      Logger.i('Pre-alert: 10 seconds remaining');
      _persistTimerState();
    }
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
          presetMode: _presetMode.name,
        );
        if (mounted) {}
      } catch (e) {
        Logger.e('Failed to record session: $e');
        if (mounted) {}
      }
    }
    // Notify session end
    if (_current == SessionType.pomodoro) {
      unawaited(SystemNotificationService.instance.notifyPomodoroEnd(
        taskName: widget.task?.title,
      ));
    }
    
    // Continuous flow: Pomodoro → Short Break → Pomodoro → Short Break → Pomodoro → Short Break → Pomodoro → Long Break → Cycle Complete
    if (_current == SessionType.pomodoro) {
      // After Pomodoro: play 5-second alarm and automatically start break
      _completedPomodoros++;
      _playAlarmForFiveSeconds();
      if (_completedPomodoros % 4 == 0) {
        // After 4th Pomodoro, go to long break
        _switchSession(SessionType.longBreak);
      } else {
        // After 1st, 2nd, 3rd Pomodoro, go to short break
        _switchSession(SessionType.shortBreak);
      }
      // Automatically start break countdown
      _startTimer();
    } else if (_current == SessionType.shortBreak) {
      // After short break, show focus check dialog before continuing
      _playAlarmForFiveSeconds();
      await _showFocusCheckDialog();
    } else if (_current == SessionType.longBreak) {
      // Long break completes the cycle
      _playAlarmForFiveSeconds();
      _handleCycleCompletion();
    }
  }

  /// Called when the user skips the current session.
  /// Saves the session locally like a normal completion, but stays on the same session type.
  Future<void> _onSkipComplete() async {
    // Save current session as skipped, then advance to next with continuous flow
    final typeBefore = _current;
    try {
      final durationMinutes = _durations[typeBefore]!.inMinutes;
      await SessionService.instance.recordCompletedSession(
        sessionType: typeBefore,
        durationMinutes: durationMinutes,
        task: widget.task,
        presetMode: _presetMode.name,
      );
      if (mounted) {}
    } catch (e) {
      Logger.e('Failed to record skipped session: $e');
      if (mounted) {}
    }

    // Continuous flow behavior
    if (typeBefore == SessionType.pomodoro) {
      // Skip Pomodoro → go to appropriate break, play 5s alarm, start break
      _completedPomodoros++;
      _playAlarmForFiveSeconds();
      if (_completedPomodoros % 4 == 0) {
        _switchSession(SessionType.longBreak);
      } else {
        _switchSession(SessionType.shortBreak);
      }
      _startTimer();
    } else if (typeBefore == SessionType.shortBreak) {
      // Skip short break → show focus check dialog
      _playAlarmForFiveSeconds();
      await _showFocusCheckDialog();
    } else {
      // Skipping the long break should end the cycle
      _playAlarmForFiveSeconds();
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
      _resetPreAlerts();
    });
    _persistTimerState();
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
            hintText: 'Min',
            suffixText: 'Min',
          );

          Widget numberField(TextEditingController c, {VoidCallback? onTap}) => SizedBox(
            width: 130, // Fixed width for all modes to prevent UI shifting
            height: 44,
            child: TextField(
              controller: c,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              readOnly: true,
              onTap: onTap,
              decoration: fieldDec('Min').copyWith(
                suffixIcon: (editable && onTap != null)
                    ? GestureDetector(
                        onTap: onTap,
                        child: const Icon(Icons.expand_more, size: 18, color: Colors.black54),
                      )
                    : const SizedBox(width: 24), // Placeholder to maintain consistent width
              ),
            ),
          );

          Future<void> pickMinutes({required String title, required int initial, required int max, required void Function(int value) onPicked, void Function(int value)? onChange}) async {
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
                      onSelectedItemChanged: (i) {
                        localSelected = i + 1;
                        if (onChange != null) onChange(localSelected);
                      },
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
            content: SizedBox(
              width: 320, // Fixed width for consistent dialog size
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                StatefulBuilder(builder: (ctx2, setLocal2) {
                  void step(int delta) {
                    final modes = PresetMode.values;
                    final i = modes.indexOf(selected);
                    final next = modes[(i + delta + modes.length) % modes.length];
                    updateFieldsFor(next);
                  }
                  Widget arrow(IconData icon, VoidCallback onTap) {
                    return InkWell(
                      onTap: onTap,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                          ],
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Icon(icon, color: _accent, size: 20),
                      ),
                    );
                  }
                  return Row(
                    children: [
                      arrow(Icons.arrow_back_ios, () => step(-1)),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _presetLabel(selected),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      arrow(Icons.arrow_forward_ios, () => step(1)),
                    ],
                  );
                }),
                const SizedBox(height: 16),
                const Text('Time', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pomodoro'),
                    numberField(
                      pomCtrl,
                      onTap: editable
                          ? () => pickMinutes(
                                title: 'Pomodoro Minutes',
                                initial: int.tryParse(pomCtrl.text) ?? _durations[SessionType.pomodoro]!.inMinutes,
                                max: 60,
                                onPicked: (val) {
                                  pomCtrl.text = '$val';
                                  setLocal(() {});
                                },
                                onChange: (val) {
                                  pomCtrl.text = '$val';
                                  setLocal(() {});
                                },
                              )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Short Break'),
                    numberField(
                      shortCtrl,
                      onTap: editable
                          ? () => pickMinutes(
                                title: 'Short Break Minutes',
                                initial: int.tryParse(shortCtrl.text) ?? _durations[SessionType.shortBreak]!.inMinutes,
                                max: 15,
                                onPicked: (val) {
                                  shortCtrl.text = '$val';
                                  setLocal(() {});
                                },
                                onChange: (val) {
                                  shortCtrl.text = '$val';
                                  setLocal(() {});
                                },
                              )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Long Break'),
                    numberField(
                      longCtrl,
                      onTap: editable
                          ? () => pickMinutes(
                                title: 'Long Break Minutes',
                                initial: int.tryParse(longCtrl.text) ?? _durations[SessionType.longBreak]!.inMinutes,
                                max: 30,
                                onPicked: (val) {
                                  longCtrl.text = '$val';
                                  setLocal(() {});
                                },
                                onChange: (val) {
                                  longCtrl.text = '$val';
                                  setLocal(() {});
                                },
                              )
                          : null,
                    ),
                  ],
                ),
                
              ],
              ),
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
                        return;
                      }
                      _stopTimer();
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
                        _current = SessionType.pomodoro;
                        _remaining = _durations[SessionType.pomodoro]!;
                        _endAt = null;
                        _resetPreAlerts();
                      });
                      _persistTimerState();
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
    int remainingSeconds = 15;
    Timer? autoCloseTimer;
    // Rounded-corner dialog matching app style with auto-dismiss in 15s
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            autoCloseTimer ??= Timer.periodic(const Duration(seconds: 1), (t) async {
              remainingSeconds--;
              setState(() {});
              if (remainingSeconds <= 0) {
                t.cancel();
                autoCloseTimer = null;
                await _stopAlarm();
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
              }
            });
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.black87),
                  const SizedBox(width: 8),
                  Text('Focus Check', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 8),
                  Text('Auto closes in ${_formatHms(remainingSeconds)}',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    autoCloseTimer?.cancel();
                    autoCloseTimer = null;
                    await _stopAlarm();
                    // End the session and return to homepage
                    _stopTimer();
                    if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                    if (mounted) {
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
                    autoCloseTimer?.cancel();
                    autoCloseTimer = null;
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
      },
    );
    _isDialogShowing = false;
  }

  Future<void> _showFocusCheckDialog() async {
    if (_isDialogShowing) return;
    _isDialogShowing = true;
    final message = _focusMessages[_rand.nextInt(_focusMessages.length)];
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
              Icon(Icons.psychology, color: Colors.black87),
              SizedBox(width: 8),
              Text('Focus Check', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () async {
                await _stopAlarm();
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                // User not focused - quit session and reset all data
                _stopTimer();
                // Reset local state to initial values
                setState(() {
                  _current = SessionType.pomodoro;
                  _remaining = _durations[SessionType.pomodoro]!;
                  _completedPomodoros = 0;
                  _isRunning = false;
                  isSessionActive = false;
                  _endAt = null;
                  _resetPreAlerts();
                });
                // Clear persisted cache so next time starts fresh
                _clearTimerCache();
                if (mounted) {
                  Navigator.of(context).pop();
                }
                _isDialogShowing = false;
              },
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _stopAlarm();
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                // User is focused - continue to next Pomodoro
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
    _isDialogShowing = false;
  }

  String _formatHms(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
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
              Text('Cycle Complete!', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          content: const Text(
              'Amazing focus! You completed the full Pomodoro cycle. Grab some water and celebrate this win 🎉'),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await _stopAlarm();
                if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                if (mounted) {
                  // Mark task as complete if there's a task
                  if (widget.task != null) {
                    await _markTaskAsComplete();
                  }
                  Navigator.of(context).pop({'cycleComplete': true});
                }
                _isDialogShowing = false;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Back to Home'),
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

  void _playTimedAlarm(Duration duration) {
    unawaited(_startAlarmLoop());
    Future.delayed(duration, () async {
      if (!mounted) return;
      await _stopAlarm();
    });
  }

  /// Plays the alarm sound for 5 seconds, then stops.
  void _playAlarmForFiveSeconds() {
    _playTimedAlarm(const Duration(seconds: 5));
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

  Future<bool> _onWillPop() async {
    // If session is running, show confirmation dialog
    if (_isRunning) {
      final shouldQuit = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Quit Session?', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            content: const Text(
              'Your focus session is still running. Are you sure you want to quit? Your progress will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No, Continue'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Yes, Quit'),
              ),
            ],
          );
        },
      );
      if (shouldQuit == true) {
        // User confirmed quit - clear all timer state so they start fresh next time
        _stopTimer();
        _clearTimerCache();
        // Reset local state to initial values
        setState(() {
          _current = SessionType.pomodoro;
          _remaining = _durations[SessionType.pomodoro]!;
          _completedPomodoros = 0;
          _isRunning = false;
          isSessionActive = false;
          _endAt = null;
          _resetPreAlerts();
        });
      }
      return shouldQuit ?? false;
    }
    return true;
  }

  void _clearTimerCache() {
    // Reset the cache to initial state
    _pomodoroTimerCache.hasData = false;
    _pomodoroTimerCache.current = SessionType.pomodoro;
    _pomodoroTimerCache.durations = {
      SessionType.pomodoro: const Duration(minutes: 25),
      SessionType.shortBreak: const Duration(minutes: 5),
      SessionType.longBreak: const Duration(minutes: 15),
    };
    _pomodoroTimerCache.presetMode = PresetMode.classic;
    _pomodoroTimerCache.remaining = const Duration(minutes: 25);
    _pomodoroTimerCache.endAt = null;
    _pomodoroTimerCache.completedPomodoros = 0;
    _pomodoroTimerCache.isRunning = false;
    _pomodoroTimerCache.isSessionActive = false;
    _pomodoroTimerCache.oneMinuteAlertSent = false;
    _pomodoroTimerCache.tenSecondAlertSent = false;
  }

  Future<void> _markTaskAsComplete() async {
    if (widget.task == null) return;
    try {
      await TaskService.instance.markManualCompletion(widget.task!);
      Logger.i('Task marked as complete: ${widget.task!.title}');
    } catch (e) {
      Logger.e('Failed to mark task as complete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () async {
              final canPop = await _onWillPop();
              if (canPop && mounted) {
                Navigator.pop(context);
              }
            },
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
        // All chips are now disabled (unclickable) for continuous flow
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
              onSelected: null, // Disabled - no manual switching
              selectedColor: _accent,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.black54,
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
    // Show Start button only when not running, no pause functionality
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(icon: Icons.refresh, onTap: _resetTimer, enabled: !_isRunning),
        const SizedBox(width: 30),
        if (!_isRunning)
          GestureDetector(
            onTap: _startTimer,
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
              child: const Icon(Icons.play_arrow, size: 40, color: Colors.white),
            ),
          )
        else
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock, size: 32, color: Colors.white),
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

  Future<void> _startAppBlockerIfConfigured() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      Logger.i('App blocker: Not Android platform');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('app_blocker_enabled') ?? false;
      if (!enabled) {
        Logger.i('App blocker: Disabled by toggle');
        return;
      }
      final pkgs = await _getBlockedPackages();
      Logger.i('App blocker: Found ${pkgs.length} blocked packages: $pkgs');
      if (pkgs.isEmpty) {
        Logger.i('App blocker: No blocked packages, skipping');
        return;
      }
      final proceed = await _confirmPermissionsIfNeeded();
      if (!proceed) {
        Logger.i('App blocker: Permissions not granted, skipping');
        return;
      }
      // Set dismiss duration to the remaining Pomodoro time (in seconds)
      final dismissDurationSeconds = _current == SessionType.pomodoro
          ? _remaining.inSeconds
          : 30;
      Logger.i('App blocker: Starting service with packages: $pkgs');
      final result = await _blockerChannel.invokeMethod('startAppBlocker', {
        'packages': pkgs,
        'dismissDurationSeconds': dismissDurationSeconds,
      });
      Logger.i('App blocker: Service start result: $result');
    } catch (e) {
      Logger.e('App blocker: Error starting service: $e');
    }
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
      
      Logger.i('App blocker: Usage Access = $usageGranted, Overlay Permission = $overlayGranted');
      
      if (usageGranted && overlayGranted) {
        Logger.i('App blocker: All permissions granted');
        return true;
      }
      if (!mounted) return false;
      
      
      if (!usageGranted) {
        
      }
      if (!overlayGranted) {
        
      }
      
      final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: const Text('Permissions Required'),
                content: Text(
                  'To block apps, you need:\n\n'
                  '${!usageGranted ? "1. Usage Access\n   Settings → Apps → Cherry Tomato → Special access → Usage access\n\n" : ""}'
                  '${!overlayGranted ? "2. Draw over other apps\n   Settings → Apps → Cherry Tomato → Special access → Display over other apps\n\n" : ""}'
                  'These are special permissions that must be enabled manually.\n\n'
                  'Tap "Open Settings" to go to the permission screens.',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Open Settings')),
                ],
              );
            },
      ) ??
          false;
      if (!proceed) {
        Logger.i('App blocker: User cancelled permission request');
        return false;
      }
      // Open settings if permissions are not granted
      if (!usageGranted) {
        Logger.i('App blocker: Opening Usage Access settings');
        await _blockerChannel.invokeMethod('openUsageAccessSettings');
      }
      if (!overlayGranted) {
        Logger.i('App blocker: Opening Overlay settings');
        await _blockerChannel.invokeMethod('openOverlaySettings');
      }
      // Give user time to grant permissions, then check again
      await Future.delayed(const Duration(seconds: 2));
      final usageGrantedAfter = await _blockerChannel.invokeMethod<bool>('isUsageAccessGranted') ?? false;
      final overlayGrantedAfter = await _blockerChannel.invokeMethod<bool>('isOverlayPermissionGranted') ?? false;
      
      Logger.i('App blocker: After settings - Usage = $usageGrantedAfter, Overlay = $overlayGrantedAfter');
      
      if (usageGrantedAfter && overlayGrantedAfter) {
        if (mounted) {}
        return true;
      } else {
        if (mounted) {}
        return false;
      }
    } catch (e) {
      Logger.e('App blocker: Error checking permissions: $e');
      return false;
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
