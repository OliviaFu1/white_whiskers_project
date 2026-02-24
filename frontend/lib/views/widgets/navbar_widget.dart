import 'package:flutter/material.dart';
import 'package:frontend/data/notifiers.dart';

class NavbarWidget extends StatelessWidget {
  const NavbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: selectedPageNotifier,
      builder: (context, selectedPage, child) {
        return NavigationBar(
          destinations: [
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
          onDestinationSelected: (value) {
            selectedPageNotifier.value = value;
          },
          selectedIndex: selectedPage,
        );
      },
    );
  }
}
