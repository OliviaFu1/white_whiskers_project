import 'package:flutter/material.dart';
import 'package:frontend/pages/medication/medication_page.dart';
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

          return Dismissible(
            key: Key(notification.id),
            background: Container(
              color: Colors.blue.shade400,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: Row(
                children: [
                  Icon(
                    notification.isRead
                        ? Icons.mark_email_unread
                        : Icons.mark_email_read,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    notification.isRead ? 'Mark Unread' : 'Mark Read',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            secondaryBackground: Container(
              color: Colors.red.shade400,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Delete',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  Icon(Icons.delete, color: Colors.white),
                ],
              ),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                if (notification.isRead) {
                  await _markAsUnread(notification);
                } else {
                  await markAsRead(notification);
                }
                return false;
              } else {
                return await _confirmDelete(notification);
              }
            },
            onDismissed: (direction) {
              if (direction == DismissDirection.endToStart) {
                _deleteNotification(notification);
              }
            },
            child: NotificationTile(
              notification: notification,
              onTap: () => _handleNotificationTap(notification),
            ),
          );
        },
      );
      },)
    );
  }

  void _handleNotificationTap(AppNotification notification) {
    markAsRead(notification);
    _switchPet(notification.petId);

    switch (notification.notificationType) {
      case NotificationType.medication:
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MedicationPage()),
        );
        break;

      case NotificationType.journal:
        selectedTabNotifier.value = AppTab.journal;
        Navigator.pop(context);
        break;

      case NotificationType.birthday:
        selectedTabNotifier.value = AppTab.myPet;
        Navigator.pop(context);
        break;
    }
  }

  void _switchPet(int? petId) {
    if (petId == null) return;
    final match = petsNotifier.value.where((p) => p.id == petId).firstOrNull;
    if (match != null) selectedPetNotifier.value = match;
  }

Future<void> markAsRead(AppNotification notification) async {
    await notificationRepository!.markRead(notification.id);
    notification.isRead = true;
    notificationsNotifier.value = List.from(notificationsNotifier.value);
  }

  Future<void> _markAsUnread(AppNotification notification) async {
    await notificationRepository!.markUnread(notification.id);
    notification.isRead = false;
    notificationsNotifier.value = List.from(notificationsNotifier.value);
  }

  Future<void> _deleteNotification(AppNotification notification) async {
    await notificationRepository!.delete(notification.id);
    notificationsNotifier.value = notificationsNotifier.value
        .where((n) => n.id != notification.id)
        .toList();
  }

  Future<bool> _confirmDelete(AppNotification notification) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete notification?'),
            content: const Text(
                'This notification will be permanently deleted.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style:
                    TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
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
    return Text.rich(
      _buildSpans(message),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  TextSpan _buildSpans(String text) {
    const normal = TextStyle(fontSize: 14, color: Colors.black54);
    const bold = TextStyle(
        fontSize: 14, color: Colors.black54, fontWeight: FontWeight.bold);

    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int cursor = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start), style: normal));
      }
      spans.add(TextSpan(text: match.group(1), style: bold));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: normal));
    }
    return TextSpan(children: spans);
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
      final m = difference.inMinutes;
      return "$m ${m == 1 ? 'minute' : 'minutes'} ago";
    }
    if (difference.inHours < 24) {
      final h = difference.inHours;
      return "$h ${h == 1 ? 'hour' : 'hours'} ago";
    }
    if (difference.inDays == 1) return "Yesterday";
    if (difference.inDays < 7) {
      return "${difference.inDays} days ago";
    }

    return "${date.month}/${date.day}/${date.year}";
  }
}
