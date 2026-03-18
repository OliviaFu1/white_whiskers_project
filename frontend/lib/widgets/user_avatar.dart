import 'package:flutter/material.dart';
import 'package:frontend/models/user.dart';

class UserAvatar extends StatelessWidget {
  final User? user;
  final double radius;

  const UserAvatar({super.key, required this.user, required this.radius});

  String get _initials {
    final first = user?.name.trim() ?? '';
    final last = user?.lastName?.trim() ?? '';
    final a = first.isNotEmpty ? first[0].toUpperCase() : '';
    final b = last.isNotEmpty ? last[0].toUpperCase() : '';
    return '$a$b';
  }

  Color get _backgroundColor {
    final initials = _initials;
    if (initials.isEmpty) return Colors.grey;
    // Derive a consistent color from the initials
    final hash = initials.codeUnits.fold(0, (acc, c) => acc + c);
    const colors = [
      Color(0xFF7986CB), // indigo
      Color(0xFF4DB6AC), // teal
      Color(0xFFFF8A65), // orange
      Color(0xFFA1887F), // brown
      Color(0xFF9575CD), // purple
      Color(0xFF4FC3F7), // light blue
      Color(0xFF81C784), // green
      Color(0xFFF06292), // pink
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoUrl;
    final initials = _initials;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    if (initials.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: _backgroundColor,
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.75,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundImage: const AssetImage('assets/images/test_user.jpg'),
    );
  }
}
