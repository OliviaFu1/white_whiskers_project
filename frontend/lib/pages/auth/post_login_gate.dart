import 'package:flutter/material.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/pages/app_shell.dart';
import 'package:frontend/pages/repositories/notification_repository.dart';
import 'package:frontend/services/notifications_service.dart';
import 'package:frontend/services/pet_store.dart';
import 'package:frontend/services/pets_api.dart';
import 'package:frontend/state/auth_state.dart';
import 'package:frontend/state/notifiers.dart';
import '../../services/account_api.dart';
import '../onboarding/onboarding_flow.dart';

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
    notificationRepository ??= ApiNotificationRepository();
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
      final data = await AccountApi.getMe();
      userNotifier.value = User.fromJson(data);

      final rawPets = await PetsApi.listPets();
      if (rawPets.isNotEmpty) {
        await PetStore.setCurrentPetId(rawPets.first["id"] as int);
        final pets = rawPets
            .map(
              (p) => Pet(
                id: p["id"] as int,
                name: (p["name"] ?? "Pet").toString(),
                photoUrl: p["photo_url"]?.toString(),
              ),
            )
            .toList();
        petsNotifier.value = pets;
        selectedPetNotifier.value = pets.first;
      } else {
        petsNotifier.value = [];
        selectedPetNotifier.value = null;
      }

      if (!mounted) return;
      setState(() {
        me = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
