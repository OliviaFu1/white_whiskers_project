import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:frontend/pages/main_pages/medication_page.dart';
import 'package:frontend/pages/main_pages/daily_checkin_page.dart';

enum DayStatus { good, bad, neutral }

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const bg = Color(0xFFFBF2EB);
  static const goodColor = Color(0xFFBFD9D6);
  static const neutralColor = Color(0xFFF2D3B8);
  static const badColor = Color(0xFFE3A8A8);

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, DayStatus> _fakeData = {};

  @override
  void initState() {
    super.initState();
    _fakeData = _generateFakeDataForMonth(_focusedDay);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                // direct to detail page
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          DayDetailsPage(date: _dateOnly(selectedDay)),
                    ),
                  );
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    return _buildDayCell(day);
                  },
                  todayBuilder: (context, day, focusedDay) {
                    return _buildDayCell(day, isToday: true);
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return _buildDayCell(day, isSelected: true);
                  },
                ),
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                    _fakeData = _generateFakeDataForMonth(_focusedDay);
                  });
                },
                headerStyle: const HeaderStyle(formatButtonVisible: false),
              ),

              const SizedBox(height: 15),
              const Text(
                "This month: 66% good",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 15),

              _actionRow(
                Icons.check_circle_outline,
                "Daily check-in",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DailyCheckinPage()),
                  );
                },
              ),
              const SizedBox(height: 4),
              _actionRow(
                Icons.medication_outlined,
                "Medication",
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MedicationPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(
    DateTime day, {
    bool isSelected = false,
    bool isToday = false,
  }) {
    final status = _fakeData[_dateOnly(day)];
    final color = switch (status) {
      DayStatus.good => goodColor,
      DayStatus.bad => badColor,
      _ => neutralColor,
    };

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Map<DateTime, DayStatus> _generateFakeDataForMonth(DateTime focused) {
    final daysInMonth = DateTime(focused.year, focused.month + 1, 0).day;
    final map = <DateTime, DayStatus>{};

    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(focused.year, focused.month, d);

      // simple repeating pattern
      final v = (d + focused.month) % 3;
      map[day] = v == 0
          ? DayStatus.good
          : v == 1
          ? DayStatus.neutral
          : DayStatus.bad;
    }
    return map;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

// TODO: day details page
class DayDetailsPage extends StatelessWidget {
  final DateTime date;
  const DayDetailsPage({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final yyyyMmDd = date.toIso8601String().split('T').first;

    return Scaffold(
      appBar: AppBar(title: Text(yyyyMmDd)),
      body: const Center(child: Text("TODO: show this day's details")),
    );
  }
}

Widget _actionRow(IconData icon, String label, {required VoidCallback onTap}) {
  return ListTile(
    dense: true,
    visualDensity: const VisualDensity(vertical: -3),
    contentPadding: EdgeInsets.zero,
    minLeadingWidth: 20,
    leading: Icon(icon, size: 20, color: const Color(0xFF6F6A67)),
    title: Text(
      label,
      style: const TextStyle(fontSize: 18, color: Color(0xFF6F6A67)),
    ),
    onTap: onTap,
  );
}
