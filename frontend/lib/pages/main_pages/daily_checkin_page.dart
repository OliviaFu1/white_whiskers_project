import 'package:flutter/material.dart';
import 'package:frontend/services/token_store.dart';
import 'package:frontend/services/pet_store.dart';
import 'package:frontend/services/calendar_api.dart';

class DailyCheckinPage extends StatefulWidget {
  const DailyCheckinPage({super.key});

  @override
  State<DailyCheckinPage> createState() => _DailyCheckinPageState();
}

class _DailyCheckinPageState extends State<DailyCheckinPage> {
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);

  DateTime _selectedDate = DateTime.now();
  String _rating = "neutral"; // good|neutral|bad
  final TextEditingController _notesCtl = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day), // allow any previous days, not future
    );

    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  String _yyyyMmDd(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-"
      "${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final access = await TokenStore.readAccess();
      if (access == null) throw "No access token found.";

      final petId = await PetStore.getCurrentPetId();
      if (petId == null) throw "No pet selected.";

      final body = <String, dynamic>{
        "pet_id": petId,
        "checkin_date": _yyyyMmDd(_selectedDate),
        "day_rating": _rating,
        "notes": _notesCtl.text.trim(),
      };

      await CalendarApi.createDailyCheckin(
        accessToken: access,
        body: body,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Daily check-in saved.")),
      );
      Navigator.of(context).pop(true); // return success
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _yyyyMmDd(_selectedDate);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "How was today?",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 14),

              // Date row
              InkWell(
                onTap: _submitting ? null : _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 10,
                        offset: Offset(0, 5),
                        color: Color(0x22000000),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: muted, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 16, color: muted, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right, color: muted),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Rating selector (minimal UI, no new packages)
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
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Rating",
                      style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _pill("Good", "good"),
                        const SizedBox(width: 10),
                        _pill("Neutral", "neutral"),
                        const SizedBox(width: 10),
                        _pill("Bad", "bad"),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Notes
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
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Notes (optional)",
                        style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _notesCtl,
                          maxLines: null,
                          expands: true,
                          decoration: const InputDecoration(
                            hintText: "Anything to remember today?",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],

              const SizedBox(height: 12),

              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        "Save",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
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
        onTap: _submitting ? null : () => setState(() => _rating = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFE7E1) : const Color(0xFFF7F5F3),
            borderRadius: BorderRadius.circular(10),
            border: selected ? Border.all(color: Colors.black, width: 1.5) : null,
          ),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(color: muted, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}