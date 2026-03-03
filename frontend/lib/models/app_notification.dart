enum NotificationType { medication, journal, birthday }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final NotificationType notificationType;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.notificationType,
    this.isRead = false,
  });
}
