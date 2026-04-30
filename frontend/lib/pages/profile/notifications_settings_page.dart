import 'package:flutter/material.dart';
import 'package:frontend/services/notification_service.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState
    extends State<NotificationsSettingsPage> {
  bool _global   = true;
  bool _dose     = true;
  bool _refill   = true;
  bool _birthday = true;
  bool _loading  = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await NotificationService.getPrefs();
    if (!mounted) return;
    setState(() {
      _global   = p.global;
      _dose     = p.dose;
      _refill   = p.refill;
      _birthday = p.birthday;
      _loading  = false;
    });
  }

  Future<void> _setGlobal(bool value) async {
    setState(() => _global = value);
    await NotificationService.setEnabled(value);
  }

  Future<void> _setCategory(String key, bool value, void Function(bool) update) async {
    setState(() => update(value));
    await NotificationService.setCategoryEnabled(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(label: 'General'),
                  Card(
                    color: Colors.white,
                    child: SwitchListTile(
                      secondary: const Icon(Icons.notifications_outlined),
                      title: const Text('Enable notifications'),
                      subtitle: const Text(
                        'Master switch for all app notifications.',
                      ),
                      value: _global,
                      onChanged: _setGlobal,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(label: 'Medication'),
                  Card(
                    color: Colors.white,
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: Icon(
                            Icons.alarm_outlined,
                            color: _global ? null : Colors.grey,
                          ),
                          title: Text(
                            'Dose reminders',
                            style: TextStyle(
                              color: _global ? null : Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            'Reminder at each medication\'s scheduled time.',
                            style: TextStyle(
                              color: _global ? null : Colors.grey,
                            ),
                          ),
                          value: _dose && _global,
                          onChanged: _global
                              ? (v) => _setCategory(
                                    NotificationService.kDoseRemindersEnabled,
                                    v,
                                    (b) => _dose = b,
                                  )
                              : null,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: Icon(
                            Icons.medication_outlined,
                            color: _global ? null : Colors.grey,
                          ),
                          title: Text(
                            'Refill alerts',
                            style: TextStyle(
                              color: _global ? null : Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            '7 days before a tracked medication runs out.',
                            style: TextStyle(
                              color: _global ? null : Colors.grey,
                            ),
                          ),
                          value: _refill && _global,
                          onChanged: _global
                              ? (v) => _setCategory(
                                    NotificationService.kRefillAlertsEnabled,
                                    v,
                                    (b) => _refill = b,
                                  )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(label: 'Pet'),
                  Card(
                    color: Colors.white,
                    child: SwitchListTile(
                      secondary: Icon(
                        Icons.cake_outlined,
                        color: _global ? null : Colors.grey,
                      ),
                      title: Text(
                        'Birthday reminders',
                        style: TextStyle(
                          color: _global ? null : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        'A reminder on each pet\'s birthday.',
                        style: TextStyle(
                          color: _global ? null : Colors.grey,
                        ),
                      ),
                      value: _birthday && _global,
                      onChanged: _global
                          ? (v) => _setCategory(
                                NotificationService.kBirthdayEnabled,
                                v,
                                (b) => _birthday = b,
                              )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
