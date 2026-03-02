import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:frontend/pages/main_pages/medication_page.dart';
import 'package:frontend/pages/main_pages/daily_checkin_page.dart';
import 'package:frontend/services/calendar_api.dart';
import 'package:frontend/services/token_store.dart';
import 'package:frontend/services/pet_store.dart';

enum DayStatus { good, bad, neutral, none }

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

  // backend-driven statuses keyed by dateOnly
  Map<DateTime, DayStatus> _statusByDay = {};

  bool _loadingMonth = false;
  String? _monthError;

  @override
  void initState() {
    super.initState();
    _loadMonthStatuses(_focusedDay);
  }

  @override
  Widget build(BuildContext context) {
    final monthGoodPct = _computeGoodPctForFocusedMonth();

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

                // direct to detail page (unchanged logic)
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
                  });
                  _loadMonthStatuses(focusedDay);
                },

                headerStyle: const HeaderStyle(formatButtonVisible: false),
              ),

              const SizedBox(height: 15),

              // keep the same layout; just dynamic content
              Text(
                _loadingMonth
                    ? "This month: …"
                    : _monthError != null
                    ? "This month: —"
                    : "This month: ${monthGoodPct.toStringAsFixed(0)}% good",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),

              if (_monthError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _monthError!,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

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
    final status = _statusByDay[_dateOnly(day)] ?? DayStatus.none;

    final color = switch (status) {
      DayStatus.good => goodColor,
      DayStatus.bad => badColor,
      DayStatus.neutral => neutralColor,
      DayStatus.none => Colors.transparent, // or a very light gray
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

  Future<void> _loadMonthStatuses(DateTime focused) async {
    setState(() {
      _loadingMonth = true;
      _monthError = null;
    });

    try {
      final accessToken = await _getAccessToken();
      final petId = await _getCurrentPetId();

      final checkins = await CalendarApi.listDailyCheckins(
        accessToken: accessToken,
        petId: petId,
      );

      // Convert to day-status map. If multiple checkins exist per day (different authors),
      // combine with: bad > neutral > good.
      final map = <DateTime, DayStatus>{};

      for (final c in checkins) {
        final dateStr = (c["checkin_date"] ?? "") as String;
        if (dateStr.isEmpty) continue;

        final d = _parseYyyyMmDd(dateStr);
        final rating = (c["day_rating"] ?? "neutral") as String;
        final s = _toDayStatus(rating);

        map[d] = _combineDayStatus(map[d], s);
      }

      setState(() {
        _statusByDay = map;
      });
    } catch (e) {
      setState(() {
        _monthError = e.toString();
        _statusByDay = {};
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMonth = false;
        });
      }
    }
  }

  double _computeGoodPctForFocusedMonth() {
    final first = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final last = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    int good = 0;
    int totalWithData = 0;

    for (int d = 1; d <= last.day; d++) {
      final day = DateTime(first.year, first.month, d);
      final s = _statusByDay[_dateOnly(day)];
      if (s == null) continue;
      totalWithData++;
      if (s == DayStatus.good) good++;
    }

    if (totalWithData == 0) return 0;
    return 100.0 * good / totalWithData;
  }

  DayStatus _toDayStatus(String dayRating) {
    switch (dayRating) {
      case "good":
        return DayStatus.good;
      case "bad":
        return DayStatus.bad;
      default:
        return DayStatus.neutral;
    }
  }

  // bad > neutral > good
  DayStatus _combineDayStatus(DayStatus? existing, DayStatus incoming) {
    if (existing == null) return incoming;
    if (existing == DayStatus.bad || incoming == DayStatus.bad) {
      return DayStatus.bad;
    }
    if (existing == DayStatus.neutral || incoming == DayStatus.neutral) {
      return DayStatus.neutral;
    }
    return DayStatus.good;
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _parseYyyyMmDd(String s) {
    final parts = s.split("-");
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  Future<String> _getAccessToken() async {
    final access = await TokenStore.readAccess();
    if (access == null) throw "No access token found.";
    return access;
  }

  Future<int> _getCurrentPetId() async {
    final petId = await PetStore.getCurrentPetId();
    if (petId == null) {
      throw "No pet selected.";
    }
    return petId;
  }
}

// Keep this in the same file for now (no page logic changes).
class DayDetailsPage extends StatefulWidget {
  final DateTime date;
  const DayDetailsPage({super.key, required this.date});

  @override
  State<DayDetailsPage> createState() => _DayDetailsPageState();
}

class _DayDetailsPageState extends State<DayDetailsPage> {
  late final String _yyyyMmDd;

  bool _loading = true;
  String? _err;

  List<Map<String, dynamic>> _checkins = [];
  List<Map<String, dynamic>> _journals = [];

  @override
  void initState() {
    super.initState();
    _yyyyMmDd = widget.date.toIso8601String().split('T').first;
    _loadDayDetails();
  }

  Future<void> _loadDayDetails() async {
    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final accessToken = await _getAccessToken();
      final petId = await _getCurrentPetId();

      final checkins = await CalendarApi.listDailyCheckins(
        accessToken: accessToken,
        petId: petId,
        date: _yyyyMmDd,
      );

      final journals = await CalendarApi.listJournalEntries(
        accessToken: accessToken,
        petId: petId,
        date: _yyyyMmDd,
      );

      setState(() {
        _checkins = checkins;
        _journals = journals;
      });
    } catch (e) {
      setState(() {
        _err = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_yyyyMmDd)),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _err != null
            ? Text(_err!)
            : Text(
                "Checkins: ${_checkins.length}\nJournals: ${_journals.length}",
                textAlign: TextAlign.center,
              ),
      ),
    );
  }

  Future<String> _getAccessToken() async {
    final access = await TokenStore.readAccess();
    if (access == null) throw "No access token found.";
    return access;
  }

  Future<int> _getCurrentPetId() async {
    final petId = await PetStore.getCurrentPetId();
    if (petId == null) {
      throw "No pet selected.";
    }
    return petId;
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
