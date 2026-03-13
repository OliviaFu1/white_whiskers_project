import 'dart:convert';
import 'package:frontend/config.dart';
import 'package:frontend/models/app_notification.dart';
import 'package:frontend/services/auth_http.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> fetchNotifications();
  Future<void> markRead(String id);
  Future<void> generateTestNotification();
}

class ApiNotificationRepository implements NotificationRepository {
  static Uri _u(String path) => Uri.parse("${AppConfig.apiBaseUrl}$path");

  final AuthHttp authHttp;
  ApiNotificationRepository(this.authHttp);

  @override
  Future<List<AppNotification>> fetchNotifications() async {
    try {
      final response = await authHttp.get(_u("/api/notifications/"));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return [];

        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          return decoded.map((json) => AppNotification.fromJson(json)).toList();
        }

        if (decoded is Map<String, dynamic> && decoded.containsKey("results")) {
          return (decoded["results"] as List)
              .map((json) => AppNotification.fromJson(json))
              .toList();
        }

        return [];
      }
      // If unauthorized → return empty instead of crashing
      if (response.statusCode == 401) {
        return [];
      }
      return [];
    } catch (e) {
      return []; // Never crash polling
    }
  }

  @override
  Future<void> markRead(String id) async {
    final response = await authHttp.patch(
      _u("/api/notifications/$id/mark-read/"),
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to mark read");
    }
  }

  @override
  Future<void> generateTestNotification() async {
    final response = await authHttp.post(
      _u("/api/notifications/generate_test/"),
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to generate test notification");
    }
  }
}
