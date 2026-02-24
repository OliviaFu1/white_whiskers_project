import 'package:flutter/material.dart';
import 'package:frontend/data/notifiers.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/pages/main_pages/calendar_page.dart';
import 'package:frontend/pages/main_pages/journal_page.dart';
import 'package:frontend/pages/main_pages/mypet_page.dart';
import 'package:frontend/pages/notifications_page.dart';
import 'package:frontend/pages/profile_page.dart';

List<Widget> pages = [CalendarPage(), JournalPage(), MypetPage()];

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppbarWidget(),
      body: ValueListenableBuilder(
        valueListenable: selectedPageNotifier,
        builder: (context, selectedPage, child) {
          return pages.elementAt(selectedPage);
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
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfilePage()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: const [
          SizedBox(width: 6),
          CircleAvatar(
            radius: 20,
            backgroundImage: AssetImage('assets/images/test_user.jpg'),
          ),
          SizedBox(width: 8),
          Text(
            'cauliflower',
            style: TextStyle(color: Colors.black, fontSize: 16),
          ),
        ],
      ),
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
    return IconButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => NotificationsPage()),
        );
      },
      icon: const Icon(Icons.notifications),
    );
  }
}

class PetsDropdown extends StatefulWidget {
  const PetsDropdown({super.key});

  @override
  State<PetsDropdown> createState() => _PetsDropdownState();
}

class _PetsDropdownState extends State<PetsDropdown> {
  final List<Pet> pets = [
    Pet(id: '0', name: 'Sausage', imageUrl: 'assets/images/test_pet.jpg'),
    Pet(id: '1', name: 'Pausage', imageUrl: 'assets/images/test_pet.jpg'),
    Pet(id: '2', name: 'Mortage', imageUrl: 'assets/images/test_pet.jpg'),
  ]; // temporary list

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Pet>(
      valueListenable: selectedPetNotificer,
      builder: (context, currentPet, child) {
        return PopupMenuButton<Pet>(
          offset: const Offset(10, 42),
          onSelected: (Pet selectedPet) {
            selectedPetNotificer.value = selectedPet;
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
  }
}

class _SelectedPetButton extends StatelessWidget {
  final Pet pet;

  const _SelectedPetButton({required this.pet});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(pet.name, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 5),
        _PetAvatar(imageUrl: pet.imageUrl, radius: 20),
      ],
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
        Expanded(child: Text(pet.name, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 3),
        _PetAvatar(imageUrl: pet.imageUrl, radius: 16),
      ],
    );
  }
}

class _PetAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;

  const _PetAvatar({required this.imageUrl, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(radius: radius, backgroundImage: AssetImage(imageUrl));
  }
}

class _Navbar extends StatelessWidget {
  const _Navbar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: selectedPageNotifier,
      builder: (context, selectedPage, child) {
        return NavigationBar(
          selectedIndex: selectedPage,
          onDestinationSelected: (value) {
            selectedPageNotifier.value = value;
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
