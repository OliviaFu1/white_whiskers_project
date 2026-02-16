import 'package:flutter/material.dart';
import 'package:frontend/data/constants.dart';
import 'package:frontend/data/notifiers.dart';
import 'package:frontend/views/pages/home_page.dart';
import 'package:frontend/views/pages/profile_page.dart';
import 'package:frontend/views/pages/settings_page.dart';
import 'package:frontend/views/widgets/navbar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

// String title = 'flutter test';
List<Widget> pages = [HomePage(), ProfilePage()];

class WidgetTree extends StatelessWidget {
  const WidgetTree({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('flutter test'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () async {
              isDarkNotifier.value = !isDarkNotifier.value;
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              await prefs.setBool(
                KConstants.themeModeKey,
                isDarkNotifier.value,
              );
            },
            icon: ValueListenableBuilder(
              valueListenable: isDarkNotifier,
              builder: (context, isDarkMode, child) {
                return isDarkMode
                    ? Icon(Icons.dark_mode)
                    : Icon(Icons.light_mode);
              },
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return SettingsPage(title: 'settings');
                  },
                ),
              );
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
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
