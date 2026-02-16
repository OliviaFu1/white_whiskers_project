import 'package:flutter/material.dart';
import 'package:frontend/views/pages/expanded_flexible_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.title});
  final String title;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  TextEditingController controller = TextEditingController();
  bool? isChecked = false;
  bool isSwitched = false;
  double slider = 0.0;
  String? dropdownItem = 'e1';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: BackButton(
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('snackbar'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 5),
                    ),
                  );
                },
                child: Text('open snackbar'),
              ),
              Divider(color: Colors.teal, thickness: 5.0, endIndent: 100.0),
              FilledButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('alert title'),
                        content: Text('alert dialogue'),
                        actions: [
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text('close'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Text('alert'),
              ),
              DropdownButton(
                value: dropdownItem,
                items: [
                  DropdownMenuItem(value: 'e1', child: Text('element1')),
                  DropdownMenuItem(value: 'e2', child: Text('element2')),
                  DropdownMenuItem(value: 'e3', child: Text('element3')),
                ],
                onChanged: (String? value) {
                  setState(() {
                    dropdownItem = value;
                  });
                },
              ),
              TextField(
                decoration: InputDecoration(border: OutlineInputBorder()),
                controller: controller,
                onEditingComplete: () {
                  setState(() {});
                },
              ),
              Text(controller.text),
              Checkbox.adaptive(
                tristate: true,
                value: isChecked,
                onChanged: (bool? value) {
                  setState(() {
                    isChecked = value;
                  });
                },
              ),
              CheckboxListTile.adaptive(
                title: Text('click me'),
                value: isChecked,
                tristate: true,
                onChanged: (bool? value) {
                  setState(() {
                    isChecked = value;
                  });
                },
              ),
              Switch.adaptive(
                value: isSwitched,
                onChanged: (bool value) {
                  setState(() {
                    isSwitched = value;
                  });
                },
              ),
              SwitchListTile.adaptive(
                value: isSwitched,
                title: Text('switch me'),
                onChanged: (bool value) {
                  setState(() {
                    isSwitched = value;
                  });
                },
              ),
              Slider.adaptive(
                max: 10.0,
                divisions: 10,
                value: slider,
                onChanged: (double value) {
                  setState(() {
                    slider = value;
                  });
                },
              ),
              InkWell(
                splashColor: Colors.teal,
                onTap: () {},
                child: Container(
                  height: 100.0,
                  width: double.infinity,
                  color: Colors.white12,
                  // child: Image.asset('assets/images/test.jpg')
                ),
              ),
              ElevatedButton(onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return ExpandedFlexiblePage();
                      },
                    ),
                  );
              }, child: Text('show flexible and expanded')),
              TextButton(onPressed: () {}, child: Text('push me')),
              OutlinedButton(onPressed: () {}, child: Text('push me')),
            ],
          ),
        ),
      ),
    );
  }
}
