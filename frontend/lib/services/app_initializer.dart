import 'package:frontend/state/notifiers.dart';

class AppInitializer {
  static Future<void> initialize() async {
    await Future.wait([loadUser(), loadPets(), loadNotifications()]);
  }
}
