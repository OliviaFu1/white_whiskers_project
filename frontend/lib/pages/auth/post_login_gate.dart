import 'package:flutter/material.dart';
import 'package:frontend/pages/app_shell.dart';
import 'package:frontend/services/notifications_service.dart';
import 'package:frontend/services/pet_store.dart';
import 'package:frontend/services/pets_api.dart';
import 'package:frontend/state/auth_state.dart';
import '../../services/auth_api.dart';
import '../../services/token_store.dart';
import '../onboarding/onboarding_flow.dart';
// import '../main_pages/mypet_page.dart';

class PostLoginGate extends StatefulWidget {
  const PostLoginGate({super.key});

  @override
  State<PostLoginGate> createState() => _PostLoginGateState();
}

class _PostLoginGateState extends State<PostLoginGate> {
  bool isLoading = true;
  String? errorText;
  Map<String, dynamic>? me;
  final NotificationRefresher refresher = NotificationRefresher();

  @override
  void initState() {
    super.initState();
    refresher.start();
    AuthState.instance.addListener(_authListener);
    _loadMe();
  }

  void _authListener() {
    if (!AuthState.instance.value) {
      refresher.stop();
    }
  }

  @override
  void dispose() {
    refresher.stop();
    AuthState.instance.removeListener(_authListener);
    super.dispose();
  }

  Future<void> _loadMe() async {
    try {
      final access = await TokenStore.readAccess();
      if (access == null) throw "No access token found.";

      final data = await AuthApi.me(accessToken: access);

      final pets = await PetsApi.listPets();
      if (pets.isNotEmpty) {
        await PetStore.setCurrentPetId(pets.first["id"] as int);
      }

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (errorText != null) {
      return Scaffold(
        body: Center(
          child: Text(errorText!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    final name = (me?["name"] ?? "").toString().trim();
    final isFirstTime = name.isEmpty;

    return isFirstTime ? const OnboardingFlow() : const AppShell();
  }
}
