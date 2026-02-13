import 'package:flutter/material.dart';
import '../services/token_store.dart';
import 'login_page.dart';
import 'profile_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: TokenStore.readAccess(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final access = snap.data;
        if (access != null && access.isNotEmpty) {
          return const ProfilePage();
        }

        return const LoginPage();
      },
    );
  }
}