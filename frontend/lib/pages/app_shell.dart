import 'package:flutter/material.dart';
import 'package:frontend/services/notifications_service.dart';
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

class _AppShellState extends State<AppShell> {
  final NotificationRefresher _refresher = NotificationRefresher();

  @override
  void initState() {
    super.initState();
    _refresher.start();
    AuthState.instance.addListener(_authListener);
  }

  void _authListener() {
    if (!AuthState.instance.value) {
      _refresher.stop();
    }
  }

  @override
  void dispose() {
    _refresher.stop();
    AuthState.instance.removeListener(_authListener);
    super.dispose();
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
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
              icon: const Icon(Icons.notifications),
              tooltip: "notifications",
            ),

            if (unreadCount > 0)
              Positioned(right: 1, top: 0, child: _Badge(count: unreadCount)),
          ],
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
