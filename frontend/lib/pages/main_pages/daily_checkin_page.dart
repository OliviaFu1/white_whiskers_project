import 'package:flutter/material.dart';
import 'package:frontend/services/pet_store.dart';
import 'package:frontend/services/calendar_api.dart';

class DailyCheckinPage extends StatefulWidget {
  final DateTime date;
  const DailyCheckinPage({super.key, required this.date});

  @override
  State<DailyCheckinPage> createState() => _DailyCheckinPageState();
}

class _DailyCheckinPageState extends State<DailyCheckinPage> {
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);

  final _notesCtl = TextEditingController();

  String? _rating;
  String? _initialRating;
  String _initialNotes = "";
  bool get _hasRating =>
      _rating == "good" || _rating == "neutral" || _rating == "bad";

  int? _checkinId;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  DateTime get _day =>
      DateTime(widget.date.year, widget.date.month, widget.date.day);

  String _yyyyMmDd(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-"
      "${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";

  bool get _dirty =>
      _rating != _initialRating || _notesCtl.text.trim() != _initialNotes;

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  @override
  void dispose() {
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _loadDay() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final petId = await PetStore.getCurrentPetId();
      if (petId == null) throw "No pet selected.";

      final dayStr = _yyyyMmDd(_day);

      final checkins = await CalendarApi.listDailyCheckins(
        petId: petId,
        date: dayStr,
      );

      final existing =
          checkins.isNotEmpty ? Map<String, dynamic>.from(checkins.first) : null;

      final ratingRaw = existing?["day_rating"];
      final rating = ratingRaw?.toString();
      final notes = (existing?["notes"] ?? "").toString();
      final id = existing?["id"];

      final normalized =
          (rating == "good" || rating == "bad" || rating == "neutral")
              ? rating
              : null;

      setState(() {
        _checkinId =
            (id is int) ? id : (id is String ? int.tryParse(id) : null);

        _rating = normalized; // null if no record -> no default selection
        _notesCtl.text = notes;

        _initialRating = normalized;
        _initialNotes = notes.trim();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_hasRating) {
      setState(() => _error = "Please select Good / Neutral / Bad.");
      return;
    }
    if (!_dirty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final petId = await PetStore.getCurrentPetId();
      if (petId == null) throw "No pet selected.";

      final body = <String, dynamic>{
        "pet_id": petId,
        "checkin_date": _yyyyMmDd(_day),
        "day_rating": _rating!, // non-null enforced by _hasRating
        "notes": _notesCtl.text.trim(),
      };

      if (_checkinId == null) {
        final res = await CalendarApi.createDailyCheckin(body: body);
        final id = res["id"];
        _checkinId =
            (id is int) ? id : (id is String ? int.tryParse(id) : null);
      } else {
        await CalendarApi.updateDailyCheckin(id: _checkinId!, body: body);
      }

      if (!mounted) return;

      setState(() {
        _initialRating = _rating;
        _initialNotes = _notesCtl.text.trim();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Daily check-in saved.")),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _yyyyMmDd(_day);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text("Daily check-in"),
        backgroundColor: bg,
        foregroundColor: muted,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "How was ${dateStr == _yyyyMmDd(DateTime.now()) ? "today" : "this day"}?",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 10,
                            offset: Offset(0, 5),
                            color: Color(0x22000000),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            color: muted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 16,
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (_checkinId != null)
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 10,
                            offset: Offset(0, 5),
                            color: Color(0x22000000),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _pill("Good", "good"),
                          const SizedBox(width: 10),
                          _pill("Neutral", "neutral"),
                          const SizedBox(width: 10),
                          _pill("Bad", "bad"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 10,
                              offset: Offset(0, 5),
                              color: Color(0x22000000),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _notesCtl,
                          onChanged: (_) => setState(() {}),
                          maxLines: null,
                          expands: true,
                          decoration: const InputDecoration(
                            hintText: "Anything to remember?",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: (_saving || !_dirty || !_hasRating) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _dirty ? "Save changes" : "Saved",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    final selected = _rating == value;
    return Expanded(
      child: InkWell(
        onTap: _saving ? null : () => setState(() => _rating = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFE7E1) : const Color(0xFFF7F5F3),
            borderRadius: BorderRadius.circular(10),
            border:
                selected ? Border.all(color: Colors.black, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}