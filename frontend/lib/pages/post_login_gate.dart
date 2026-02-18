import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../services/token_store.dart';
import 'onboarding_flow.dart';
import 'mypet_page.dart';

class PostLoginGate extends StatefulWidget {
  const PostLoginGate({super.key});

  @override
  State<PostLoginGate> createState() => _PostLoginGateState();
}

class _PostLoginGateState extends State<PostLoginGate> {
  bool isLoading = true;
  String? errorText;
  Map<String, dynamic>? me;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final access = await TokenStore.readAccess();
      if (access == null) throw "No access token found.";

      final data = await AuthApi.me(accessToken: access);

      setState(() {
        me = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorText = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorText != null) {
      return Scaffold(
        body: Center(child: Text(errorText!, style: const TextStyle(color: Colors.red))),
      );
    }

    final name = (me?["name"] ?? "").toString().trim();
    final isFirstTime = name.isEmpty;

    return isFirstTime ? const OnboardingFlow() : const MypetPage();
  }
}