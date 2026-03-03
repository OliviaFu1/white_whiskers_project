import 'package:frontend/state/notifiers.dart';

class AppInitializer {
  static Future<void> initialize() async {
    await loadPets();
    await loadNotifications();
  }
}
