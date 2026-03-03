import 'package:frontend/models/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> fetchNotifications();
}

//TODO: Change to backend
class FakeNotificationRepository implements NotificationRepository {
  @override
  Future<List<AppNotification>> fetchNotifications() async {
    await Future.delayed(const Duration(seconds: 1)); //network delay

    return [
      AppNotification(
        id: '1',
        title: 'Medication time',
        message: 'Did you give sausage medication?',
        createdAt: DateTime.now(),
        notificationType: NotificationType.medication,
      ),
      AppNotification(
        id: '2',
        title: 'Journal reminder',
        message: 'Write in the journal',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        notificationType: NotificationType.journal,
      ),
      AppNotification(
        id: '3',
        title: 'Pausage\'s birthday',
        message: 'Happy birthday pausage!!',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        notificationType: NotificationType.birthday,
      ),
    ];
  }
}
