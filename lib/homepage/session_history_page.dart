import 'package:flutter/material.dart';
import 'package:tomatonator/services/session_service.dart';
import 'package:tomatonator/services/sync_service.dart';
import 'package:tomatonator/models/pomodoro_session.dart';

/// Session History: Shows local and remote Pomodoro sessions merged,
/// indicates which entries are synced to the server.
class SessionHistoryPage extends StatefulWidget {
  const SessionHistoryPage({super.key});

  @override
  State<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends State<SessionHistoryPage> {
  List<PomodoroSession> _sessions = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessions = await SessionService.instance.mergedSessionsForCurrentUser();
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTime(int ms) {
    // Display time in UTC+08:00 regardless of device timezone
    final dtUtc = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    final dtPlus8 = dtUtc.add(const Duration(hours: 8));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dtPlus8.year}-${two(dtPlus8.month)}-${two(dtPlus8.day)} ${two(dtPlus8.hour)}:${two(dtPlus8.minute)}';
  }


  /// Handle manual sync and refresh the session list
  Future<void> _handleManualSync() async {
    await SyncService.instance.manualSync(context);
    // Refresh the session list after sync
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Session History'),
        backgroundColor: Colors.white,
        actions: [
          // Always show Sync Now; when not logged in, a helpful snackbar is shown.
          IconButton(
            onPressed: _handleManualSync,
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Now',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
                ? ListView(children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: $_error'),
                    )
                  ])
                : (_sessions.isEmpty)
                    ? ListView(children: const [
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No sessions yet'),
                        ),
                      ])
                    : ListView.separated(
                        itemCount: _sessions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = _sessions[i];
                          return ListTile(
                            title: Text('${s.duration} min'),
                            subtitle: Text(_formatTime(s.completedAt)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  s.synced ? Icons.cloud_done : Icons.cloud_off,
                                  color: s.synced ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(s.synced ? 'Synced' : 'Local'),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}