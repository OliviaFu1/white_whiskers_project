import 'package:flutter/material.dart';
import 'package:frontend/state/auth_state.dart';
import 'login_page.dart';
import 'post_login_gate.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await AuthState.instance.initialize();
    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {

    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ValueListenableBuilder<bool>(
      valueListenable: AuthState.instance,
      builder: (context, isLoggedIn, _) {
        return isLoggedIn ? const PostLoginGate() : const LoginPage();
      },
    );
  }
}
