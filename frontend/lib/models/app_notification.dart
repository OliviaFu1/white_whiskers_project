enum NotificationType { medication, journal, birthday }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final NotificationType notificationType;
  final int? petId;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.notificationType,
    this.petId,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      title: json['title'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at']),
      notificationType: NotificationType.values.firstWhere(
        (e) => e.name == json['notification_type'],
        orElse: () => NotificationType.medication,
      ),
      petId: json['pet_id'] as int?,
    );
  }
}
