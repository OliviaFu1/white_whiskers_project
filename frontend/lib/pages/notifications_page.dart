import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('notifications page')),
      body: SingleChildScrollView(
        child: Column(
          children: [ListTile(title: Text('notification 1'), onTap: () {})],
        ),
      ),
    );
  }
}
