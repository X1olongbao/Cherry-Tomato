import 'package:flutter/material.dart';
import 'package:tomatonator/models/pomodoro_session.dart';
import 'package:tomatonator/services/session_service.dart';
import 'package:tomatonator/services/sync_service.dart';

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
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        itemCount: _sessions.length,
                        itemBuilder: (context, i) => _SessionHistoryCard(
                          session: _sessions[i],
                          index: i + 1,
                        ),
                      ),
      ),
    );
  }
}

class _SessionHistoryCard extends StatelessWidget {
  const _SessionHistoryCard({
    required this.session,
    required this.index,
  });

  final PomodoroSession session;
  final int index;

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    return '${_two(dt.month)}/${_two(dt.day)}/${dt.year} '
        '${_two(dt.hour)}:${_two(dt.minute)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _modeLabel() {
    switch (session.sessionType) {
      case 'short_break':
        return 'Short Break • ${session.duration} min';
      case 'long_break':
        return 'Long Break • ${session.duration} min';
      case 'pomodoro':
      default:
        return 'Pomodoro • ${session.duration} min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final finishedMs = session.finishedAt ?? session.completedAt;
    final finished = _formatDate(finishedMs);
    final created = session.taskCreatedAt != null
        ? _formatDate(session.taskCreatedAt!)
        : 'Unknown';
    final due = session.taskDueAt != null
        ? _formatDate(session.taskDueAt!)
        : 'No due date';
    final syncColor = session.synced ? const Color(0xFF2E7D32) : Colors.orange;
    final syncLabel = session.synced ? 'Synced' : 'Local only';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        border: Border(
          left: BorderSide(color: syncColor, width: 6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Checkbox(
                  value: true,
                  onChanged: null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(height: 12),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: syncColor, width: 4),
                  ),
                  child: Icon(
                    Icons.check,
                    color: syncColor,
                    size: 30,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.taskName?.isNotEmpty == true
                              ? session.taskName!
                              : 'Task #$index',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: syncColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              session.synced
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              size: 18,
                              color: syncColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              syncLabel,
                              style: TextStyle(
                                color: syncColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _HistoryDetailRow(
                    label: 'Date created - due date',
                    value: '$created — $due',
                  ),
                  const SizedBox(height: 8),
                  _HistoryDetailRow(
                    label: 'Date finished',
                    value: finished,
                  ),
                  const SizedBox(height: 8),
                  _HistoryDetailRow(
                    label: 'Pomodoro mode',
                    value: _modeLabel(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDetailRow extends StatelessWidget {
  const _HistoryDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}