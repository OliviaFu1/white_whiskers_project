import 'package:flutter/material.dart';

class ExpandedFlexiblePage extends StatelessWidget {
  const ExpandedFlexiblePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(child: Container(color: Colors.teal, height: 20.0)),
              Flexible(
                child: Container(
                  color: Colors.orange,
                  height: 20.0,
                  child: Text('wheiorhweoirhoiewhroiewhroihewrhoi'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
