import 'package:flutter/material.dart';
import 'package:frontend/models/app_notification.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/pages/repositories/notification_repository.dart';
import 'package:frontend/pages/repositories/pet_repository.dart';

// final Pet _defaultPet = Pet(
//   id: '0',
//   name: 'Sausage',
//   imageUrl: 'assets/images/test_pet.jpg',
// );

Future<void> loadPets() async {
  final pets = await petRepository.fetchPets();

  petsNotifier.value = pets;

  if (pets.isNotEmpty) {
    selectedPetNotifier.value = pets.first;
  }
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

final petsNotifier = ValueNotifier<List<Pet>>([]);
final ValueNotifier<Pet?> selectedPetNotifier = ValueNotifier<Pet?>(null);
final PetRepository petRepository = FakePetRepository();
