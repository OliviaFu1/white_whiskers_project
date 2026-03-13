import 'package:flutter/material.dart';
import 'package:frontend/state/notifiers.dart';
import 'package:frontend/models/app_notification.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}


class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('notifications page')),
      body: ValueListenableBuilder<List<AppNotification>>(valueListenable: notificationsNotifier, builder: (context, notifications, child) {
        if(notifications.isEmpty) {
          return const Center(child: Text('no notifications'),);
        }
        return ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];

          return NotificationTile(
            notification: notification,
            onTap: () => _handleNotificationTap(notification),
          );
        },
      );
      },)
    );
  }

  void _handleNotificationTap(AppNotification notification) {
    markAsRead(notification);

    switch (notification.notificationType) {
      case NotificationType.medication:
        selectedTabNotifier.value = AppTab.calendar;
        break;

      case NotificationType.journal:
        selectedTabNotifier.value = AppTab.journal;
        break;

      case NotificationType.birthday:
        selectedTabNotifier.value = AppTab.myPet;
        break;
    }

    Navigator.pop(context);
  }

Future<void> markAsRead(AppNotification notification) async {
    await notificationRepository!.markRead(notification.id);

    final list = notificationsNotifier.value;

    notification.isRead = true;
    notificationsNotifier.value = List.from(list);
  }
}

class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: notification.isRead ? Colors.transparent : Colors.grey,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 120,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _NotificationIcon(type: notification.notificationType),
                const SizedBox(width: 12),
                Expanded(
                  child: _NotificationContent(notification: notification),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  final NotificationType type;

  const _NotificationIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case NotificationType.medication:
        return const Icon(Icons.medication);
      case NotificationType.journal:
        return const Icon(Icons.book);
      case NotificationType.birthday:
        return const Icon(Icons.cake_rounded);
    }
  }
}

class _NotificationContent extends StatelessWidget {
  final AppNotification notification;

  const _NotificationContent({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitleRow(notification: notification),
        const SizedBox(height: 4),
        _MessageText(message: notification.message),
        const SizedBox(height: 6),
        _TimeText(notification: notification),
      ],
    );
  }
}

class _TitleRow extends StatelessWidget {
  final AppNotification notification;

  const _TitleRow({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            notification.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: notification.isRead
                  ? FontWeight.w500
                  : FontWeight.bold,
            ),
          ),
        ),
        if (!notification.isRead) const _UnreadDot(),
      ],
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MessageText extends StatelessWidget {
  final String message;

  const _MessageText({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 14, color: Colors.black54),
    );
  }
}

class _TimeText extends StatelessWidget {
  // final DateTime date;
  final AppNotification notification;

  const _TimeText({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatTime(notification.createdAt),
      style: TextStyle(
        fontSize: 12,
        color: notification.isRead ? Colors.grey : Colors.black,
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return "Just now";
    if (difference.inMinutes < 60) {
      return "${difference.inMinutes} minutes ago";
    }
    if (difference.inHours < 24) {
      return "${difference.inHours} hours ago";
    }
    if (difference.inDays == 1) return "Yesterday";
    if (difference.inDays < 7) {
      return "${difference.inDays} days ago";
    }

    return "${date.month}/${date.day}/${date.year}";
  }
}
