import 'package:flutter/material.dart';
import 'package:frontend/views/pages/notifications_page.dart';
import 'package:frontend/views/pages/profile_page.dart';
import 'package:frontend/views/widgets/pets_dropdown.dart';

class AppbarWidget extends StatelessWidget implements PreferredSizeWidget {
  const AppbarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.teal, //get rid of this, just for test only
      leadingWidth: 160,
      leading: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) {
                return ProfilePage();
              },
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            SizedBox(width: 6),
            CircleAvatar(
              radius: 20,
              backgroundImage: AssetImage('assets/images/test_user.jpg'),
            ),
            SizedBox(width: 8),
            Text(
              'cauliflower',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
      actions: [
        PetsDropdown(),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) {
                  return NotificationsPage();
                },
              ),
            );
          },
          icon: Icon(Icons.notifications),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60.0);
}
