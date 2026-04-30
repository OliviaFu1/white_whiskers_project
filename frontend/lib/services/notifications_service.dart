import 'dart:async';

import 'package:frontend/models/pet.dart';
import 'package:frontend/services/medication_api.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/state/notifiers.dart';

class NotificationRefresher {
  Timer? _timer;

  void start() {
    tick();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => tick());
  }

  void stop() {
    _timer?.cancel();
  }

  Future<void> tick() async {
    final prefs = await NotificationService.getPrefs();

    // Process medication dose reminders and refill alerts for ALL pets so that
    // in-app notifications stay in sync with local OS notifications, which are
    // scheduled for every pet's medications regardless of which pet is selected.
    // Fall back to the selected pet when petsNotifier hasn't been populated yet
    // (e.g. the user hasn't visited the My Pet tab since launch).
    if (prefs.global && prefs.dose) {
      final ignoreBefore = await NotificationService.getResumeTs();
      final allPets = petsNotifier.value;
      final toProcess = allPets.isNotEmpty
          ? allPets
          : (selectedPetNotifier.value != null
              ? [selectedPetNotifier.value!]
              : <Pet>[]);
      for (final pet in toProcess) {
        try {
          await MedicationApi.processDueDoses(
            petId: pet.id,
            ignoreBefore: ignoreBefore,
          );
        } catch (_) {}
      }
    }

    // Check birthday notifications for all pets (not pet-specific).
    if (prefs.global && prefs.birthday) {
      try {
        await MedicationApi.checkBirthdays();
      } catch (_) {}
    }

    await loadNotifications();
  }
}
