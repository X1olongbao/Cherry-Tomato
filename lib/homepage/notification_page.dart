import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  @override
  void initState() {
    super.initState();
    // Clear unread badge when opening the page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Notification',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            )),
        actions: [
          ValueListenableBuilder<List<AppNotification>>(
            valueListenable: NotificationService.instance.notifications,
            builder: (context, list, _) {
              final canClear = list.isNotEmpty;
              return IconButton(
                icon: const Icon(Icons.cleaning_services_outlined,
                    color: Colors.black),
                tooltip: 'Clear all',
                onPressed: canClear
                    ? () {
                        NotificationService.instance.clearAll();
                      }
                    : null,
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<AppNotification>>(
        valueListenable: NotificationService.instance.notifications,
        builder: (context, list, _) {
          final today = DateTime.now();
          final todayList = list.where((n) => _isSameDay(n.createdAt, today)).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Today',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  )),
              const SizedBox(height: 12),
              if (todayList.isEmpty)
                _emptyCard()
              else
                ...todayList.map((n) => _notificationCard(n)).toList(),
            ],
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _emptyCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: const Text('No notifications today',
          style: TextStyle(color: Colors.black54)),
    );
  }

  Widget _notificationCard(AppNotification n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.celebration, color: Colors.orange, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.message,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 6),
                Text(_formatTime(n.createdAt),
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 12,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    int h = dt.hour % 12;
    if (h == 0) h = 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}