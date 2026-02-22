import 'package:flutter/material.dart';
import 'package:frontend/data/notifiers.dart';
import 'package:frontend/views/pages/calendar_page.dart';
import 'package:frontend/views/pages/journal_page.dart';
import 'package:frontend/views/pages/my_pets_page.dart';
import 'package:frontend/views/widgets/appbar_widget.dart';
import 'package:frontend/views/widgets/navbar_widget.dart';

List<Widget> pages = [CalendarPage(), JournalPage(), MyPetsPage()];

class WidgetTree extends StatelessWidget {
  const WidgetTree({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppbarWidget(),
      body: ValueListenableBuilder(
        valueListenable: selectedPageNotifier,
        builder: (context, selectedPage, child) {
          return pages.elementAt(selectedPage);
        },
      ),
      bottomNavigationBar: NavbarWidget(),
    );
  }
}
