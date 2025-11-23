import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/system_notification_service.dart';
import '../services/task_service.dart';
import '../models/task.dart';
import '../services/task_reminder_service.dart';
import '../services/database_service.dart';
import '../utilities/logger.dart';

class _InstalledApp {
  final String name;
  final String package;
  const _InstalledApp(this.name, this.package);
}

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  final _oldPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  bool _oldVisible = false;
  bool _newVisible = false;

  bool notificationsEnabled = true;
  bool appBlockerEnabled = true;
  String? _selectedTaskId;

  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedApps = <String>{};
  final Map<String, Uint8List> _appIcons = <String, Uint8List>{};
  bool _isScanning = false;
  List<_InstalledApp> _installedApps = [];
  static const MethodChannel _appsChannel = MethodChannel('com.example.tomatonator/installed_apps');
  static const MethodChannel _blockerChannel = MethodChannel('com.example.tomatonator/installed_apps');
  static const String _blockedKey = 'blocked_packages';

  bool get _isOAuthLogin {
    final fUser = fb.FirebaseAuth.instance.currentUser;
    if (fUser == null) return false;
    final providers = fUser.providerData.map((p) => p.providerId).toList();
    // Common OAuth providers; expand if you add more.
    return providers.contains('google.com') || providers.contains('github.com') || providers.contains('apple.com');
  }

  Future<void> _handleChangePassword() async {
    if (_isOAuthLogin) return;
    final oldPwd = _oldPwdCtrl.text.trim();
    final newPwd = _newPwdCtrl.text.trim();
    if (oldPwd.isEmpty || newPwd.isEmpty) {
      if (!mounted) return;
      return;
    }
    try {
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (email == null || email.isEmpty) {
        if (!mounted) return;
        return;
      }
      // Basic verification: try signing in with old password (non-destructive)
      await AuthService.instance.signIn(email: email, password: oldPwd);
      // If successful, update current user password
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPwd));
      if (!mounted) return;
      _oldPwdCtrl.clear();
      _newPwdCtrl.clear();
      // Optional: pop after success
      // navigator.pop();
    } catch (e) {
      if (!mounted) return;
    }
  }


  @override
  void initState() {
    super.initState();
    _loadBlockedApps();
    _loadNotificationState();
  }

  Future<void> _loadNotificationState() async {
    final enabled = await SystemNotificationService.instance.areNotificationsEnabled();
    setState(() {
      notificationsEnabled = enabled;
    });
  }

  Future<void> _scanApps() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    setState(() => _isScanning = true);
    try {
      final raw = await _appsChannel.invokeMethod<List<dynamic>>('getInstalledApps');
      final apps = (raw ?? const [])
          .map((e) {
            final m = (e as Map).cast<String, dynamic>();
            final name = (m['name'] ?? '').toString();
            final pkg = (m['package'] ?? '').toString();
            return _InstalledApp(name, pkg);
          })
          .where((a) => a.package.isNotEmpty)
          .toList(growable: false)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _installedApps = apps;
      });
      // Load icons for all apps after scanning
      await _ensureIconsForSelected();
      if (apps.isEmpty) {
      } else {
      }
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _loadBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_blockedKey) ?? <String>[];
    setState(() {
      _selectedApps
        ..clear()
        ..addAll(list);
    });
    await _ensureIconsForSelected();
  }

  Future<void> _saveBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_blockedKey, _selectedApps.toList());
    await _ensureIconsForSelected();
  }

  Future<void> _ensureIconsForSelected() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    // Load icons for all installed apps, not just selected ones
    for (final app in _installedApps) {
      if (_appIcons.containsKey(app.package)) continue;
      final bytes = await _fetchAppIcon(app.package);
      if (bytes != null && mounted) {
        setState(() {
          _appIcons[app.package] = bytes;
        });
      }
    }
  }

  Future<Uint8List?> _fetchAppIcon(String package) async {
    try {
      final bytes = await _appsChannel.invokeMethod<Uint8List>('getAppIcon', {
        'package': package,
      });
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showAppPicker() async {
    if (_installedApps.isEmpty) {
      await _scanApps();
    }
    if (!mounted) return;
    final localSearch = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = localSearch.text.trim().toLowerCase();
            final items = (_installedApps.isEmpty ? const <_InstalledApp>[] : _installedApps)
                .where((a) => query.isEmpty || a.name.toLowerCase().contains(query) || a.package.toLowerCase().contains(query))
                .toList(growable: false);
            
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Select Apps to Block',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_isScanning)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () async {
                              await _scanApps();
                              setSheetState(() {});
                            },
                            tooltip: 'Rescan apps',
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: localSearch,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search apps...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  // App list
                  Expanded(
                    child: _isScanning && _installedApps.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.apps, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      query.isEmpty ? 'No apps found' : 'No apps match your search',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.75,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  return _buildAppCard(items[index], setSheetState);
                                },
                              ),
                  ),
                  // Footer with selected count and done button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedApps.length} app${_selectedApps.length != 1 ? 's' : ''} selected',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Done',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    localSearch.dispose();
  }

  Widget _buildAppCard(_InstalledApp app, StateSetter setSheetState) {
    final selected = _selectedApps.contains(app.package);
    final iconBytes = _appIcons[app.package];
    
    return GestureDetector(
      onTap: () async {
        setState(() {
          if (selected) {
            _selectedApps.remove(app.package);
          } else {
            _selectedApps.add(app.package);
            // Load icon if not already loaded
            if (!_appIcons.containsKey(app.package)) {
              _fetchAppIcon(app.package).then((bytes) {
                if (bytes != null && mounted) {
                  setState(() {
                    _appIcons[app.package] = bytes;
                  });
                }
              });
            }
          }
        });
        await _saveBlockedApps();
        setSheetState(() {});
      },
      child: Container(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE53935).withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFE53935) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: iconBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            iconBytes,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.apps, color: Colors.black54, size: 32),
                ),
                if (selected)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                app.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? const Color(0xFFE53935) : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _ensureInterceptionPermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final usageGranted = await _blockerChannel.invokeMethod<bool>('isUsageAccessGranted') ?? false;
    final overlayGranted = await _blockerChannel.invokeMethod<bool>('isOverlayPermissionGranted') ?? false;
    if (!usageGranted) {
      await _blockerChannel.invokeMethod('openUsageAccessSettings');
      if (!mounted) return;
    }
    if (!overlayGranted) {
      await _blockerChannel.invokeMethod('openOverlaySettings');
      if (!mounted) return;
    }
  }

  Future<void> _startInterception() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    // Prompt for permissions if needed before starting
    final proceed = await _confirmPermissionsIfNeeded();
    if (!proceed) {
      setState(() => appBlockerEnabled = false);
      return;
    }
    await _ensureInterceptionPermissions();
    final pkgs = _selectedApps.toList();
    try {
      await _blockerChannel.invokeMethod('startAppBlocker', { 'packages': pkgs });
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
    }
  }

  Future<void> _stopInterception() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _blockerChannel.invokeMethod('stopAppBlocker');
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
    }
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
                title: const Text('Permissions Required'),
                content: const Text(
                    'Cherry Tomato needs Usage Access and "Draw over other apps" permissions to block apps. Grant access now?'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Grant')),
                ],
              );
            },
          ) ??
          false;
    } catch (_) {
      return true; // If check fails, attempt to proceed and handle in ensure
    }
  }

  @override
  void dispose() {
    _oldPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = Colors.grey.shade100;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Privacy & Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Debug logging is disabled for privacy. No diagnostic logs are recorded.',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionHeader('Security'),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tileHeader(Icons.lock_outline, 'Change Password'),
                const SizedBox(height: 12),
                IgnorePointer(
                  ignoring: _isOAuthLogin,
                  child: Opacity(
                    opacity: _isOAuthLogin ? 0.6 : 1.0,
                    child: Column(
                      children: [
                        _passwordField('Old Password', _oldPwdCtrl, _oldVisible, () {
                          setState(() => _oldVisible = !_oldVisible);
                        }),
                        const SizedBox(height: 12),
                        _passwordField('New Password', _newPwdCtrl, _newVisible, () {
                          setState(() => _newVisible = !_newVisible);
                        }),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isOAuthLogin ? null : _handleChangePassword,
                            child: const Text('Confirm Change'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isOAuthLogin) ...[
                  const SizedBox(height: 12),
                  _helpText(
                    'Password cannot be changed because you logged in using Google. '
                    'Manage your password via your Google account.',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('App Blocker & Permissions'),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tileHeader(Icons.notifications_none, 'Notification Toggle'),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Switch(
                    value: notificationsEnabled,
                    onChanged: (val) async {
                      setState(() => notificationsEnabled = val);
                      Logger.i('Notification toggle: $val');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Notifications ${val ? 'enabled' : 'disabled'}')),
                        );
                      }
                      await SystemNotificationService.instance.setNotificationsEnabled(val);
                      if (!val) {
                        // Cancel all notifications when disabled
                        await SystemNotificationService.instance.cancelAllNotifications();
                      }
                    },
                    activeThumbColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tileHeader(Icons.science, 'Notification Self-Test'),
                const SizedBox(height: 8),
                _helpText('Use these buttons to verify notifications work in foreground/background.'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () async {
                            await SystemNotificationService.instance.notifyPomodoroStart(taskName: 'Test');
                          },
                          child: const Text('Show Now'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () async {
                            final when = DateTime.now().add(const Duration(seconds: 10));
                            await SystemNotificationService.instance.scheduleGeneralReminder(
                              title: 'Test Notification',
                              message: 'Scheduled +10 seconds',
                              reminderTime: when,
                            );
                          },
                          child: const Text('Schedule +10s'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<List<Task>>(
                  valueListenable: TaskService.instance.activeTasks,
                  builder: (context, tasks, _) {
                    final items = tasks;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedTaskId,
                                items: items
                                    .map((t) => DropdownMenuItem(
                                          value: t.id,
                                          child: Text(t.title, overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (val) => setState(() => _selectedTaskId = val),
                                decoration: const InputDecoration(
                                  labelText: 'Select a task',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: (_selectedTaskId == null)
                                    ? null
                                    : () async {
                                        final t = items.firstWhere((x) => x.id == _selectedTaskId);
                                        final when = DateTime.now().add(const Duration(minutes: 1));
                                        await SystemNotificationService.instance.scheduleTaskReminder(
                                          taskId: t.id,
                                          taskTitle: t.title,
                                          reminderTime: when,
                                          reminderType: 'due_soon',
                                          customMessage: '"${t.title}" is due in 1 minute.',
                                        );
                                      },
                                child: const Text('Schedule Selected +1m'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: (_selectedTaskId == null)
                                      ? null
                                      : () async {
                                          final t = items.firstWhere((x) => x.id == _selectedTaskId);
                                          await TaskReminderService.instance.scheduleRemindersForTask(t);
                                        },
                                  child: const Text('Reschedule From due_at'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: (_selectedTaskId == null)
                                      ? null
                                      : () async {
                                          final t = items.firstWhere((x) => x.id == _selectedTaskId);
                                          final rows = await DatabaseService.instance.getTaskReminders(t.id);
                                          if (!mounted) return;
                                          await showDialog<void>(
                                            context: context,
                                            builder: (ctx) {
                                              return AlertDialog(
                                                title: const Text('Scheduled Reminders'),
                                                content: SizedBox(
                                                  width: double.maxFinite,
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: rows.isEmpty
                                                        ? [const Text('None')]
                                                        : rows.map((m) {
                                                            final ts = DateTime.fromMillisecondsSinceEpoch((m['reminder_time'] as num).toInt());
                                                            final type = (m['reminder_type'] ?? '').toString();
                                                            return Text('$type • ${ts.toLocal()}');
                                                          }).toList(),
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                  child: const Text('Show Scheduled'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () async {
                      final when = DateTime.now().add(const Duration(minutes: 1));
                      await SystemNotificationService.instance.scheduleTaskReminder(
                        taskId: 'test-task',
                        taskTitle: 'Sample Task',
                        reminderTime: when,
                        reminderType: 'due_soon',
                        customMessage: 'Sample Task is due in 1 minute.',
                      );
                    },
                    child: const Text('Schedule Task Reminder +1m'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tileHeader(Icons.block, 'App Blocker Toggle'),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Switch(
                    value: appBlockerEnabled,
                    onChanged: (val) async {
                      setState(() => appBlockerEnabled = val);
                      if (val) {
                        await _startInterception();
                      } else {
                        await _stopInterception();
                      }
                    },
                    activeThumbColor: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.apps, color: Colors.black87),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'App Selection',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _helpText('Select which apps to block during Pomodoro sessions. Applied to all sessions.'),
                const SizedBox(height: 16),
                // Selected apps display with integrated plus button
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 280), // Fit 3 rows initially, scrollable if more
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: GridView.builder(
                          shrinkWrap: true,
                          physics: const AlwaysScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _selectedApps.length + 1, // Plus button + all apps (no limit)
                          itemBuilder: (context, index) {
                            // First item is the plus button
                            if (index == 0) {
                              return GestureDetector(
                                onTap: () async {
                                  if (_installedApps.isEmpty || _isScanning) {
                                    await _scanApps();
                                  }
                                  if (mounted) {
                                    await _showAppPicker();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: _isScanning
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                                                ),
                                              )
                                            : Icon(
                                                Icons.add,
                                                color: Colors.grey.shade600,
                                                size: 20,
                                              ),
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          'Add',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            // App icons (index - 1 because index 0 is the plus button)
                            final appIndex = index - 1;
                            if (appIndex >= _selectedApps.length) {
                              return const SizedBox.shrink();
                            }
                            
                            final pkg = _selectedApps.elementAt(appIndex);
                            final info = _installedApps.firstWhere(
                              (a) => a.package == pkg,
                              orElse: () => _InstalledApp(pkg.split('.').last, pkg),
                            );
                            final iconBytes = _appIcons[pkg];
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedApps.remove(pkg);
                                });
                                _saveBlockedApps();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: iconBytes != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: Image.memory(
                                                    iconBytes,
                                                    width: 48,
                                                    height: 48,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : const Icon(Icons.apps, color: Colors.black54, size: 18),
                                        ),
                                        Positioned(
                                          top: -3,
                                          right: -3,
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 9,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        info.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    );
  }

  Widget _tileHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.black87),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _helpText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: Colors.black54),
    );
  }

  Widget _passwordField(String label, TextEditingController ctrl, bool visible, VoidCallback onToggle) {
    return TextField(
      controller: ctrl,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // 2xl rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
