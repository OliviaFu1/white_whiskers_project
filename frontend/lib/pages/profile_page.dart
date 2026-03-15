import 'package:flutter/material.dart';
import 'package:frontend/main.dart';
import 'package:frontend/pages/auth/auth_gate.dart';
import 'package:frontend/state/auth_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthState.instance.logout();

    if (!context.mounted) return;

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('profile page')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () => _logout(context),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}
