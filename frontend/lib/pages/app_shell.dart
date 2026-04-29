import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/pages/medication/medication_page.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/services/notifications_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/state/auth_state.dart';
import 'package:frontend/state/notifiers.dart';
import 'package:frontend/models/app_notification.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/widgets/user_avatar.dart';
import 'package:frontend/pages/main_pages/calendar_page.dart';
import 'package:frontend/pages/main_pages/journal_page.dart';
import 'package:frontend/pages/main_pages/mypet_page.dart';
import 'package:frontend/pages/notifications_page.dart';
import 'package:frontend/pages/profile/profile_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final NotificationRefresher _refresher = NotificationRefresher();

  /// Pet id from a notification payload that arrived before pets were loaded.
  /// Applied and cleared by [_applyPendingPetId] once petsNotifier has values.
  int? _pendingPetId;

  @override
  void initState() {
    super.initState();
    _refresher.start();
    WidgetsBinding.instance.addObserver(this);
    AuthState.instance.addListener(_authListener);
    pendingMedicationNavigation.addListener(_onMedicationNavigation);
    petsNotifier.addListener(_applyPendingPetId);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Await so SharedPreferences writes from onNotificationTap complete
      // before _checkPendingNavigation tries to read them (cold-launch fix).
      await NotificationService.handlePendingLaunch();
      await _checkPendingNavigation();
    });
  }

  /// Selects the pet from [_pendingPetId] as soon as pets are available.
  void _applyPendingPetId() {
    final id = _pendingPetId;
    if (id == null) return;
    final pets = petsNotifier.value;
    if (pets.isEmpty) return;
    final match = pets.where((p) => p.id == id).toList();
    if (match.isNotEmpty) selectedPetNotifier.value = match.first;
    _pendingPetId = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingNavigation();
      _refresher.tick();
    }
  }

  /// Checks shared_preferences for a pending navigation written by the
  /// notification tap handler (which may run in a background isolate).
  Future<void> _checkPendingNavigation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('pending_medication_nav') != true) return;
      await prefs.remove('pending_medication_nav');
      if (!mounted) return;

      // Parse the payload to find out which pet and notification type fired.
      final payloadStr = prefs.getString('pending_medication_payload');
      String notifType = 'medication';
      if (payloadStr != null) {
        try {
          final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
          notifType = payload['type']?.toString() ?? 'medication';
          final petId = payload['pet_id'];
          if (petId != null) {
            final id = petId is int ? petId : int.tryParse(petId.toString());
            if (id != null) {
              final pets = petsNotifier.value;
              final match = pets.where((p) => p.id == id).toList();
              if (match.isNotEmpty) {
                selectedPetNotifier.value = match.first;
              } else {
                // Pets not loaded yet — apply once petsNotifier fires.
                _pendingPetId = id;
              }
            }
          }
        } catch (_) {}
      }

      if (notifType == 'birthday') {
        // Switch to the My Pet tab — no push needed.
        selectedTabNotifier.value = AppTab.myPet;
      } else {
        DateTime? initialDate;
        final dateStr = prefs.getString('pending_medication_date');
        if (dateStr != null) {
          initialDate = DateTime.tryParse(dateStr);
          await prefs.remove('pending_medication_date');
        }
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MedicationPage(initialDate: initialDate),
          ),
        );
      }
      await handleBackendNotificationIfPending();
    } catch (_) {}
  }

  void _authListener() {
    if (!AuthState.instance.value) {
      _refresher.stop();
    }
  }

  @override
  void dispose() {
    _refresher.stop();
    WidgetsBinding.instance.removeObserver(this);
    AuthState.instance.removeListener(_authListener);
    pendingMedicationNavigation.removeListener(_onMedicationNavigation);
    petsNotifier.removeListener(_applyPendingPetId);
    super.dispose();
  }

  /// Fast path: fires immediately when the callback ran on the main isolate.
  void _onMedicationNavigation() {
    if (pendingMedicationNavigation.value) {
      pendingMedicationNavigation.value = false;
      // _checkPendingNavigation will handle the actual push + backend call.
      _checkPendingNavigation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppbarWidget(),
      body: ValueListenableBuilder<AppTab>(
        valueListenable: selectedTabNotifier,
        builder: (context, selectedTab, child) {
          switch (selectedTab) {
            case AppTab.calendar:
              return const CalendarPage();
            case AppTab.journal:
              return const JournalPage();
            case AppTab.myPet:
              return const MypetPage();
          }
        },
      ),
      bottomNavigationBar: const _Navbar(),
    );
  }
}

class AppbarWidget extends StatelessWidget implements PreferredSizeWidget {
  const AppbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leadingWidth: 160,
      backgroundColor: Color(0xFFFBF2EB),
      leading: const _ProfileSection(),
      actions: const [_PetsSection(), _NotificationsButton()],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60.0);
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<User?>(
      valueListenable: userNotifier,
      builder: (context, user, child) {
        final name = user?.name ?? '';
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfilePage()),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE0D4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(user: user, radius: 22),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PetsSection extends StatelessWidget {
  const _PetsSection();

  @override
  Widget build(BuildContext context) {
    return PetsDropdown();
  }
}

class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: notificationsNotifier,
      builder: (context, notifications, child) {
        final unreadCount = notifications.where((n) => !n.isRead).length;
        return IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );
          },
          tooltip: "notifications",
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications),
              if (unreadCount > 0)
                Positioned(
                  right: -5,
                  top: -6,
                  child: _Badge(count: unreadCount),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      child: Center(
        child: Text(
          count > 10 ? '10+' : count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class PetsDropdown extends StatefulWidget {
  const PetsDropdown({super.key});

  @override
  State<PetsDropdown> createState() => _PetsDropdownState();
}

class _PetsDropdownState extends State<PetsDropdown> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Pet>>(
      valueListenable: petsNotifier,
      builder: (context, pets, child) {
        return ValueListenableBuilder<Pet?>(
          valueListenable: selectedPetNotifier,
          builder: (context, currentPet, child) {
            if (currentPet == null) {
              return const SizedBox();
            }
            return PopupMenuButton<Pet>(
              position: PopupMenuPosition.under,
              constraints: const BoxConstraints(
                minWidth: 160,
                maxWidth: 200,
                maxHeight: 260,
              ),
              onSelected: (Pet selectedPet) {
                selectedPetNotifier.value = selectedPet;
              },
              itemBuilder: (context) {
                return pets
                    .where((pet) => pet.id != currentPet.id)
                    .map((pet) => _PetMenuItem(pet: pet))
                    .toList();
              },
              child: _SelectedPetButton(pet: currentPet),
            );
          },
        );
      },
    );
  }
}

class _SelectedPetButton extends StatelessWidget {
  final Pet pet;

  const _SelectedPetButton({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE0D4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PetAvatar(photoUrl: pet.photoUrl, radius: 12),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: Text(
              pet.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.expand_more, size: 15, color: Colors.black54),
        ],
      ),
    );
  }
}

class _PetMenuItem extends PopupMenuItem<Pet> {
  _PetMenuItem({required Pet pet})
    : super(
        value: pet,
        child: _PetMenuItemContent(pet: pet),
      );
}

class _PetMenuItemContent extends StatelessWidget {
  final Pet pet;

  const _PetMenuItemContent({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PetAvatar(photoUrl: pet.photoUrl, radius: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            pet.name,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _PetAvatar extends StatelessWidget {
  final String? photoUrl;
  final double radius;

  const _PetAvatar({required this.photoUrl, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      child: Icon(Icons.pets, size: radius, color: Colors.grey.shade600),
    );
  }
}

class _Navbar extends StatelessWidget {
  const _Navbar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTab>(
      valueListenable: selectedTabNotifier,
      builder: (context, selectedTab, child) {
        return NavigationBar(
          selectedIndex: AppTab.values.indexOf(selectedTab),
          onDestinationSelected: (index) {
            selectedTabNotifier.value = AppTab.values[index];
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.library_books),
              label: 'journal',
            ),
            NavigationDestination(
              icon: Icon(Icons.question_mark_outlined),
              label: 'my pet',
            ),
          ],
        );
      },
    );
  }
}
