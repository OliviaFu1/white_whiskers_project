import 'dart:async';

import 'package:frontend/state/notifiers.dart';

class NotificationRefresher {
  Timer? _timer;

  void start() {
    // Refresh immediately
    loadNotifications();

    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => loadNotifications(),
    );
  }

  void stop() {
    _timer?.cancel();
  }
}
