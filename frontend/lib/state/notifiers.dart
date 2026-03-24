import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/models/app_notification.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/pages/repositories/notification_repository.dart';
import 'package:frontend/pages/repositories/pet_repository.dart';
import 'package:frontend/services/api_client.dart';


Future<void> loadPets() async {
  final pets = await petRepository.fetchPets();

  petsNotifier.value = pets;

  if (pets.isEmpty) return;

  final currentId = selectedPetNotifier.value?.id;
  final stillExists = currentId != null && pets.any((p) => p.id == currentId);
  if (!stillExists) {
    selectedPetNotifier.value = pets.first;
  }
}

Future<void> loadUser() async {
  try {
    final res = await ApiClient.get("/api/accounts/me/");
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      userNotifier.value = User.fromJson(data);
    }
  } catch (_) {}
}

Future<void> loadNotifications() async {
  if (notificationRepository == null) return;

  final notifications = await notificationRepository!.fetchNotifications();

  notificationsNotifier.value = notifications;
}

enum AppTab { calendar, journal, myPet }

final selectedTabNotifier = ValueNotifier<AppTab>(AppTab.calendar);
// final unreadNotificationsNotifier = ValueNotifier<int>(0);
final notificationsNotifier = ValueNotifier<List<AppNotification>>([]);
NotificationRepository? notificationRepository;

final userNotifier = ValueNotifier<User?>(null);
final petsNotifier = ValueNotifier<List<Pet>>([]);
final ValueNotifier<Pet?> selectedPetNotifier = ValueNotifier<Pet?>(null);
final PetRepository petRepository = RealPetRepository();
