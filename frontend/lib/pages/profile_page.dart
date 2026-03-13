import 'package:flutter/material.dart';
import 'package:frontend/state/notifiers.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Text('profile page'),
          ElevatedButton(
            onPressed: () async {
              await notificationRepository!.generateTestNotification();
              await loadNotifications();
            },
            child: Text("Generate Test Notification"),
          ),
        ],
      ),
    );
  }
}
