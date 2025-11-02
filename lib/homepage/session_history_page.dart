import 'package:flutter/material.dart';
import 'package:tomatonator/services/session_service.dart';
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
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Session History'),
        backgroundColor: Colors.white,
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