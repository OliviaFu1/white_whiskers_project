import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:frontend/pages/main_pages/medication_page.dart';
import 'package:frontend/pages/main_pages/daily_checkin_page.dart';
import 'package:frontend/pages/main_pages/day_details_page.dart';
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

  Map<DateTime, DayStatus> _statusByDay = {};
  final Set<DateTime> _daysWithCheckin = {};

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllCheckins();
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final hasCheckinToday = _daysWithCheckin.contains(today);

    final (allPct, allN) = _computeGoodPctRange(
      endDayInclusive: today,
      daysBack: 0,
    );
    final (pct28, n28) = _computeGoodPctRange(
      endDayInclusive: today,
      daysBack: 28,
    );
    final (pct7, n7) = _computeGoodPctRange(
      endDayInclusive: today,
      daysBack: 7,
    );

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
                headerStyle: const HeaderStyle(formatButtonVisible: false),

                enabledDayPredicate: (day) {
                  final today = _dateOnly(DateTime.now());
                  return !_dateOnly(
                    day,
                  ).isAfter(today); // allow today + past only
                },

                onDaySelected: (selectedDay, focusedDay) {
                  final today = _dateOnly(DateTime.now());
                  final sel = _dateOnly(selectedDay);

                  // block future clicks
                  if (sel.isAfter(today)) return;

                  setState(() => _focusedDay = focusedDay);

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DayDetailsPage(date: sel),
                    ),
                  );
                },

                onPageChanged: (focusedDay) =>
                    setState(() => _focusedDay = focusedDay),

                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) =>
                      _buildDayCell(day),
                  todayBuilder: (context, day, focusedDay) =>
                      _buildDayCell(day, isToday: true),
                  disabledBuilder: (context, day, focusedDay) =>
                      _buildDayCell(day, isDisabled: true),
                ),
              ),

              const SizedBox(height: 12),

              _loading
                  ? const _PctBlockLoading()
                  : _PctBlock(
                      error: _error,
                      allPct: allPct,
                      allN: allN,
                      pct28: pct28,
                      n28: n28,
                      pct7: pct7,
                      n7: n7,
                    ),

              const SizedBox(height: 12),

              _actionRow(
                Icons.check_circle_outline,
                "Daily check-in",
                iconColor: hasCheckinToday
                    ? Colors.green
                    : const Color(0xFF6F6A67),
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const DailyCheckinPage()),
                  );
                  if (changed == true) {
                    await _loadAllCheckins();
                  }
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
    bool isToday = false,
    bool isDisabled = false,
  }) {
    final d0 = _dateOnly(day);
    final status = _statusByDay[d0] ?? DayStatus.none;

    final bgColor = switch (status) {
      DayStatus.good => goodColor,
      DayStatus.bad => badColor,
      DayStatus.neutral => neutralColor,
      DayStatus.none => Colors.transparent,
    };

    final textColor = isDisabled
        ? Colors.black.withValues()
        : Colors.black;

    return Opacity(
      opacity: isDisabled ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: isToday ? Border.all(color: Colors.black, width: 1.5) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
        ),
      ),
    );
  }

  Future<void> _loadAllCheckins() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final accessToken = await _getAccessToken();
      final petId = await _getCurrentPetId();

      final checkins = await CalendarApi.listDailyCheckins(
        accessToken: accessToken,
        petId: petId,
      );

      final statusMap = <DateTime, DayStatus>{};
      final daysWith = <DateTime>{};

      for (final c in checkins) {
        final dateStr = (c["checkin_date"] ?? "") as String;
        if (dateStr.isEmpty) continue;

        final d = _parseYyyyMmDd(dateStr);
        daysWith.add(d);

        final rating = (c["day_rating"] ?? "neutral") as String;
        final s = _toDayStatus(rating);

        statusMap[d] = _combineDayStatus(statusMap[d], s);
      }

      setState(() {
        _statusByDay = statusMap;
        _daysWithCheckin
          ..clear()
          ..addAll(daysWith);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _statusByDay = {};
        _daysWithCheckin.clear();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  (double pct, int n) _computeGoodPctRange({
    required DateTime endDayInclusive,
    required int daysBack, // 0 => all-time
  }) {
    int good = 0;
    int total = 0;

    if (daysBack == 0) {
      for (final s in _statusByDay.values) {
        total++;
        if (s == DayStatus.good) good++;
      }
      return (total == 0 ? 0.0 : 100.0 * good / total, total);
    }

    final end = _dateOnly(endDayInclusive);
    final start = _dateOnly(end.subtract(Duration(days: daysBack - 1)));

    for (final entry in _statusByDay.entries) {
      final d = entry.key;
      if (d.isBefore(start) || d.isAfter(end)) continue;
      total++;
      if (entry.value == DayStatus.good) good++;
    }

    return (total == 0 ? 0.0 : 100.0 * good / total, total);
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

  DayStatus _combineDayStatus(DayStatus? existing, DayStatus incoming) {
    if (existing == null) return incoming;
    if (existing == DayStatus.bad || incoming == DayStatus.bad)
      {return DayStatus.bad;}
    if (existing == DayStatus.neutral || incoming == DayStatus.neutral)
      {return DayStatus.neutral;}
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
    if (petId == null) throw "No pet selected.";
    return petId;
  }
}

class _PctBlockLoading extends StatelessWidget {
  const _PctBlockLoading();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 16, fontWeight: FontWeight.w500);
    return const Column(
      children: [
        Text("All-time: …", style: style),
        SizedBox(height: 6),
        Text("Past 28 days: …", style: style),
        SizedBox(height: 6),
        Text("Past 7 days: …", style: style),
      ],
    );
  }
}

class _PctBlock extends StatelessWidget {
  final String? error;
  final double allPct;
  final int allN;
  final double pct28;
  final int n28;
  final double pct7;
  final int n7;

  const _PctBlock({
    required this.error,
    required this.allPct,
    required this.allN,
    required this.pct28,
    required this.n28,
    required this.pct7,
    required this.n7,
  });

  String _fmtPct(double pct) => "${pct.toStringAsFixed(0)}%";

  Widget _lineWithOptionalHelp({
    required String label,
    required bool ok,
    required String okText,
    required String helpText,
  }) {
    const style = TextStyle(fontSize: 16, fontWeight: FontWeight.w500);

    if (ok) {
      return Text("$label: $okText", style: style);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("$label: —", style: style),
        const SizedBox(width: 6),
        Tooltip(
          message: helpText,
          waitDuration: const Duration(milliseconds: 200),
          child: const Icon(Icons.help_outline, size: 16),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lineAll = Text(
      "All-time: ${_fmtPct(allPct)} good",
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    );

    final line28 = _lineWithOptionalHelp(
      label: "Past 28 days",
      ok: n28 >= 15,
      okText: "${_fmtPct(pct28)} good",
      helpText: "Need at least 15 check-ins in the past 28 days",
    );

    final line7 = _lineWithOptionalHelp(
      label: "Past 7 days",
      ok: n7 >= 4,
      okText: "${_fmtPct(pct7)} good",
      helpText: "Need at least 4 check-ins in the past 7 days",
    );

    return Column(
      children: [
        lineAll,
        const SizedBox(height: 6),
        line28,
        const SizedBox(height: 6),
        line7,
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

Widget _actionRow(
  IconData icon,
  String label, {
  required VoidCallback onTap,
  Color iconColor = const Color(0xFF6F6A67),
}) {
  return ListTile(
    dense: true,
    visualDensity: const VisualDensity(vertical: -3),
    contentPadding: EdgeInsets.zero,
    minLeadingWidth: 20,
    leading: Icon(icon, size: 20, color: iconColor),
    title: Text(
      label,
      style: const TextStyle(fontSize: 18, color: Color(0xFF6F6A67)),
    ),
    onTap: onTap,
  );
}
