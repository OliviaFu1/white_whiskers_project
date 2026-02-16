import 'package:flutter/material.dart';
import 'package:frontend/data/constants.dart';
import 'package:frontend/views/pages/course_page.dart';
import 'package:frontend/views/widgets/container_widget.dart';
import 'package:frontend/views/widgets/hero_widget.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    List<String> list = [
      KValue.basicLayout,
      KValue.keyConcepts,
      KValue.cleanUI,
      KValue.fixBugs,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 10.0),
            HeroWidget(title: 'flutter test', nextPage: CoursePage()),
            SizedBox(height: 5.0),
            Column(
              children: List.generate(list.length, (index) {
                return ContainerWidget(
                  title: list.elementAt(index),
                  description: 'temp description',
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
