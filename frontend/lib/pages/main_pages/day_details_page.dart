import 'package:flutter/material.dart';
import 'package:frontend/services/pet_store.dart';
import 'package:frontend/services/calendar_api.dart';
import 'package:frontend/pages/main_pages/daily_checkin_page.dart';

class DayDetailsPage extends StatefulWidget {
  final DateTime date;
  const DayDetailsPage({super.key, required this.date});

  @override
  State<DayDetailsPage> createState() => _DayDetailsPageState();
}

class _DayDetailsPageState extends State<DayDetailsPage> {
  static const muted = Color(0xFF676767);
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  bool _changed = false;

  late final PageController _pageCtl;

  late final DateTime _anchorDay;
  late DateTime _currentDay;

  // days back allow scrolling
  static const int _daysBack = 50;
  late final int _initialPage = _daysBack;

  // allow forward until today
  late int _maxPage;

  bool _loading = true;
  String? _err;

  List<Map<String, dynamic>> _checkins = [];
  List<Map<String, dynamic>> _journals = [];

  DateTime get _today => _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _anchorDay = _dateOnly(widget.date);

    // pages: 0.._maxPage, with _initialPage corresponding to anchor day
    _maxPage = _initialPage + _today.difference(_anchorDay).inDays;
    if (_maxPage < _initialPage) {
      _maxPage = _initialPage;
    }

    _currentDay = _anchorDay;
    _pageCtl = PageController(initialPage: _initialPage);
    _loadForDay(_currentDay);
  }

  @override
  void dispose() {
    _pageCtl.dispose();
    super.dispose();
  }

  // ---------- date helpers ----------
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _fmt(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-"
      "${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";

  bool _isFuture(DateTime d) => _dateOnly(d).isAfter(_today);

  DateTime _dayForPage(int pageIndex) =>
      _anchorDay.add(Duration(days: pageIndex - _initialPage));

  // ---------- data ----------
  Future<void> _loadForDay(DateTime day) async {
    final yyyyMmDd = _fmt(day);

    setState(() {
      _loading = true;
      _err = null;
    });

    try {
      final petId = await _getCurrentPetId();

      final checkins = await CalendarApi.listDailyCheckins(
        petId: petId,
        date: yyyyMmDd,
      );

      final journals = await CalendarApi.listJournalEntries(
        petId: petId,
        date: yyyyMmDd,
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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddCheckin() async {
    if (_isFuture(_currentDay)) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DailyCheckinPage(date: _currentDay)),
    );

    if (changed == true) {
      _changed = true;
      await _loadForDay(_currentDay);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final title = _fmt(_currentDay);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!mounted) return;
        final nav = Navigator.of(context);
        if (nav.canPop()) nav.pop(_changed);
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: bg,
          foregroundColor: muted,
          elevation: 0,
        ),

        // PageView handles swipe (bounded: can go back, but cannot go into future)
        body: PageView.builder(
          controller: _pageCtl,
          itemCount: _maxPage + 1, // limits forward to today
          onPageChanged: (i) async {
            final d = _dayForPage(i);
            setState(() => _currentDay = d);
            await _loadForDay(d);
          },
          itemBuilder: (context, i) {
            final d = _dayForPage(i);

            // Render only the currently selected page
            if (d != _currentDay) return const SizedBox.shrink();

            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_err != null) {
              return Center(
                child: Text(
                  _err!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => _loadForDay(_currentDay),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      _sectionTitle("Daily check-in"),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add),
                        color: muted,
                        tooltip: "Add check-in",
                        onPressed: _openAddCheckin,
                      ),
                    ],
                  ),
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
            );
          },
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
    if (_checkins.isEmpty) {
      return _emptyCard("No check-in for this day.");
    }
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
    final name = (obj["author_name"] ?? "").toString().trim();
    return name;
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
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return s;
    try {
      final d = DateTime.parse(s);
      return _fmt(_dateOnly(d));
    } catch (_) {
      return s;
    }
  }

  Future<int> _getCurrentPetId() async {
    final petId = await PetStore.getCurrentPetId();
    if (petId == null) throw "No pet selected.";
    return petId;
  }
}
