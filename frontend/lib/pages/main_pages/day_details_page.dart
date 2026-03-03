import 'package:flutter/material.dart';
import 'package:frontend/services/pet_store.dart';
import 'package:frontend/services/calendar_api.dart';

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

  static const muted = Color(0xFF676767);
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);

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
      final petId = await _getCurrentPetId();

      final checkins = await CalendarApi.listDailyCheckins(
        petId: petId,
        date: _yyyyMmDd,
      );

      final journals = await CalendarApi.listJournalEntries(
        petId: petId,
        date: _yyyyMmDd,
      );

      if (!mounted) return;
      setState(() {
        _checkins = checkins;
        _journals = journals;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(_yyyyMmDd),
        backgroundColor: bg,
        foregroundColor: muted,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
          ? Center(
              child: Text(
                _err!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDayDetails,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle("Daily check-in"),
                  const SizedBox(height: 8),
                  _buildCheckinCard(),

                  const SizedBox(height: 16),

                  _sectionTitle("Journals"),
                  const SizedBox(height: 8),
                  ..._buildJournalCards(),
                  if (_journals.isEmpty)
                    _emptyCard("No journal entries for this day."),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: accent,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 5),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _emptyCard(String text) {
    return _card(
      child: Text(text, style: const TextStyle(color: muted)),
    );
  }

  // ------- Daily checkin rendering -------

  Widget _buildCheckinCard() {
    if (_checkins.isEmpty) return _emptyCard("No check-in for this day.");

    // If there are multiple (e.g., multiple family members), show them all stacked.
    return Column(children: _checkins.map((c) => _checkinItem(c)).toList());
  }

  Widget _checkinItem(Map<String, dynamic> c) {
    final rating = (c["day_rating"] ?? "neutral").toString();
    final notes = (c["notes"] ?? "").toString().trim();
    final author = _displayAuthor(c);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ratingPill(rating),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    author.isEmpty ? " " : author,
                    style: const TextStyle(
                      color: muted,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(notes, style: const TextStyle(color: muted)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ratingPill(String rating) {
    final label = rating == "good"
        ? "Good"
        : rating == "bad"
        ? "Bad"
        : "Neutral";

    // keep it simple: no custom colors, consistent style
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5F3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(color: muted, fontWeight: FontWeight.w800),
      ),
    );
  }

  String _displayAuthor(Map<String, dynamic> obj) {
    // handle common backend shapes
    final a = obj["author"] ?? obj["author_user"] ?? obj["author_user_id"];
    if (a is Map) {
      final name = (a["name"] ?? a["email"] ?? "").toString();
      return name;
    }
    if (a != null) return "User $a";
    return "";
  }

  // ------- Journal rendering -------

  List<Widget> _buildJournalCards() {
    if (_journals.isEmpty) return [];

    return _journals.map((j) {
      final title = (j["title"] ?? "").toString().trim();
      final text = (j["text"] ?? "").toString().trim();
      final tag = (j["tag"] ?? "").toString().trim();
      final visibility = (j["visibility"] ?? "").toString().trim();
      final date = _displayEntryDate(j["entry_date"]);
      final author = _displayAuthor(j);

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: tag + visibility + date
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (tag.isNotEmpty) _smallPill(tag),
                  if (visibility.isNotEmpty) _smallPill(visibility),
                  if (date.isNotEmpty)
                    Text(date, style: const TextStyle(color: muted)),
                ],
              ),

              if (author.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  author,
                  style: const TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],

              if (title.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],

              if (text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(text, style: const TextStyle(color: muted)),
              ],
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _smallPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5F3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
      ),
    );
  }

  String _displayEntryDate(dynamic rawDate) {
    if (rawDate == null) return "";

    final s = rawDate.toString().trim();
    if (s.isEmpty) return "";

    // If backend already sends "YYYY-MM-DD", just return it
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) {
      return s;
    }

    // Fallback: try parsing and formatting
    try {
      final d = DateTime.parse(s);
      return "${d.year.toString().padLeft(4, '0')}-"
          "${d.month.toString().padLeft(2, '0')}-"
          "${d.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return s;
    }
  }

  // ------- Auth/pet -------

  Future<int> _getCurrentPetId() async {
    final petId = await PetStore.getCurrentPetId();
    if (petId == null) throw "No pet selected.";
    return petId;
  }
}
