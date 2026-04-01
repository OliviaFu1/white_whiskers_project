import 'package:flutter/material.dart';
import 'package:frontend/services/pet_store.dart';
import 'package:frontend/services/calendar_api.dart';
import 'package:frontend/state/notifiers.dart';
import 'package:frontend/models/pet.dart';

class DailyCheckinPage extends StatefulWidget {
  final DateTime date;

  // showAllPets = true  -> swipe through all pets
  // showAllPets = false -> show only one pet (used from DayDetailsPage)
  final bool showAllPets;
  final int? petId;
  final String? petName;
  final int? initialPetId;

  const DailyCheckinPage({
    super.key,
    required this.date,
    this.showAllPets = false,
    this.petId,
    this.petName,
    this.initialPetId,
  });

  @override
  State<DailyCheckinPage> createState() => _DailyCheckinPageState();
}

class _DailyCheckinPageState extends State<DailyCheckinPage> {
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);

  final PageController _pageController = PageController();

  List<Map<String, dynamic>> _pets = [];
  int _currentPage = 0;

  final Map<int, TextEditingController> _notesCtlByPet = {};
  final Map<int, String?> _ratingByPet = {};
  final Map<int, String?> _initialRatingByPet = {};
  final Map<int, String> _initialNotesByPet = {};
  final Map<int, int?> _checkinIdByPet = {};

  bool _loading = true;
  bool _saving = false;
  String? _error;

  DateTime get _day =>
      DateTime(widget.date.year, widget.date.month, widget.date.day);

  String _yyyyMmDd(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-"
      "${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _petName(Map<String, dynamic> pet) {
    final name = (pet["name"] ?? "").toString().trim();
    return name.isEmpty ? "Your pet" : name;
  }

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final ctl in _notesCtlByPet.values) {
      ctl.dispose();
    }
    super.dispose();
  }

  bool _hasRatingFor(int petId) {
    final r = _ratingByPet[petId];
    return r == "good" || r == "neutral" || r == "bad";
  }

  bool _isDirtyFor(int petId) {
    final ctl = _notesCtlByPet[petId];
    if (ctl == null) return false;
    return _ratingByPet[petId] != _initialRatingByPet[petId] ||
        ctl.text.trim() != (_initialNotesByPet[petId] ?? "");
  }

  Future<void> _loadDay() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      List<Map<String, dynamic>> petsToUse = [];

      if (widget.showAllPets) {
        final models = List<Pet>.from(petsNotifier.value);
        if (models.isEmpty) throw "No pets found.";

        petsToUse = models
            .map((p) => {"id": p.id, "name": p.name, "photo_url": p.photoUrl})
            .toList();
      } else {
        final id = widget.petId ?? await PetStore.getCurrentPetId();
        if (id == null) throw "No pet selected.";

        final models = List<Pet>.from(petsNotifier.value);
        Pet? matched;
        for (final p in models) {
          if (p.id == id) {
            matched = p;
            break;
          }
        }

        petsToUse = [
          {
            "id": id,
            "name": widget.petName ?? matched?.name ?? "",
            "photo_url": matched?.photoUrl,
          },
        ];
      }

      final dayStr = _yyyyMmDd(_day);

      for (final pet in petsToUse) {
        final petId = pet["id"] as int;

        final checkins = await CalendarApi.listDailyCheckins(
          petId: petId,
          date: dayStr,
        );

        final existing = checkins.isNotEmpty
            ? Map<String, dynamic>.from(checkins.first)
            : null;

        final ratingRaw = existing?["day_rating"];
        final rating = ratingRaw?.toString();
        final notes = (existing?["notes"] ?? "").toString();
        final id = existing?["id"];

        final normalized =
            (rating == "good" || rating == "bad" || rating == "neutral")
            ? rating
            : null;

        _notesCtlByPet[petId]?.dispose();
        _notesCtlByPet[petId] = TextEditingController(text: notes);
        _ratingByPet[petId] = normalized;
        _initialRatingByPet[petId] = normalized;
        _initialNotesByPet[petId] = notes.trim();
        _checkinIdByPet[petId] = (id is int)
            ? id
            : (id is String ? int.tryParse(id) : null);
      }

      int initialIndex = 0;
      if (widget.showAllPets && widget.initialPetId != null) {
        final idx = petsToUse.indexWhere((p) => p["id"] == widget.initialPetId);
        if (idx >= 0) initialIndex = idx;
      }

      if (!mounted) return;

      setState(() {
        _pets = petsToUse;
        _currentPage = initialIndex;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageController.hasClients && initialIndex > 0) {
          _pageController.jumpToPage(initialIndex);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePet(int petId, {bool popAfter = false}) async {
    final ctl = _notesCtlByPet[petId];
    if (ctl == null) return;

    if (!_hasRatingFor(petId)) {
      setState(() => _error = "Please select Good / Neutral / Bad.");
      return;
    }

    if (!_isDirtyFor(petId)) {
      if (popAfter && mounted) {
        Navigator.of(context).pop(true);
      }
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await PetStore.setCurrentPetId(petId);

      final body = <String, dynamic>{
        "pet_id": petId,
        "checkin_date": _yyyyMmDd(_day),
        "day_rating": _ratingByPet[petId]!,
        "notes": ctl.text.trim(),
      };

      final checkinId = _checkinIdByPet[petId];

      if (checkinId == null) {
        final res = await CalendarApi.createDailyCheckin(body: body);
        final id = res["id"];
        _checkinIdByPet[petId] = (id is int)
            ? id
            : (id is String ? int.tryParse(id) : null);
      } else {
        await CalendarApi.updateDailyCheckin(id: checkinId, body: body);
      }

      if (!mounted) return;

      setState(() {
        _initialRatingByPet[petId] = _ratingByPet[petId];
        _initialNotesByPet[petId] = ctl.text.trim();
      });

      if (popAfter) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dotIndicators() {
    if (_pets.length <= 1) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pets.length, (i) {
        final selected = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 16 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? accent : accent.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildPetCheckinPage({
    required int petId,
    required String petName,
    required bool isLast,
  }) {
    final notesCtl = _notesCtlByPet[petId]!;
    final hasSaved = _checkinIdByPet[petId] != null;
    final dirty = _isDirtyFor(petId);
    final hasRating = _hasRatingFor(petId);
    final dateStr = _yyyyMmDd(_day);
    final promptDay = _isToday(_day) ? "today" : "this day";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "How was $petName $promptDay?",
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              const Icon(Icons.calendar_today_outlined, color: muted, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 16,
                    color: muted,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasSaved)
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
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
              _pillForPet(petId, "Good", "good"),
              const SizedBox(width: 10),
              _pillForPet(petId, "Neutral", "neutral"),
              const SizedBox(width: 10),
              _pillForPet(petId, "Bad", "bad"),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 140,
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
            controller: notesCtl,
            onChanged: (_) => setState(() {}),
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              hintText: "What made today feel this way?",
              border: InputBorder.none,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        ],
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: (_saving || !dirty || !hasRating)
              ? null
              : () async {
                  await _savePet(petId);

                  if (!mounted) return;

                  if (widget.showAllPets && !isLast) {
                    await _pageController.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  } else {
                    Navigator.of(context).pop(true);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            disabledBackgroundColor: accent.withValues(alpha: 0.38),
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
                  widget.showAllPets
                      ? (isLast ? "Save" : "Save & next")
                      : (dirty ? "Save changes" : "Saved"),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
        if (widget.showAllPets && !isLast) const SizedBox(height: 4),
      ],
    );
  }

  Widget _pillForPet(int petId, String label, String value) {
    final selected = _ratingByPet[petId] == value;

    return Expanded(
      child: InkWell(
        onTap: _saving
            ? null
            : () => setState(() => _ratingByPet[petId] = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFE7E1) : const Color(0xFFF7F5F3),
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: Colors.black, width: 1.5)
                : null,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.showAllPets ? "Daily check-in" : "Daily check-in"),
        backgroundColor: bg,
        foregroundColor: muted,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _pets.isEmpty
              ? const Center(
                  child: Text("No pets found.", style: TextStyle(color: muted)),
                )
              : Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _pets.length,
                        onPageChanged: (i) {
                          if (!mounted) return;
                          setState(() {
                            _currentPage = i;
                            _error = null;
                          });
                        },
                        itemBuilder: (context, index) {
                          final pet = _pets[index];
                          final petId = pet["id"] as int;
                          final petName = _petName(pet);

                          return _buildPetCheckinPage(
                            petId: petId,
                            petName: petName,
                            isLast: index == _pets.length - 1,
                          );
                        },
                      ),
                    ),
                    if (_pets.length > 1) ...[
                      const SizedBox(height: 10),
                      _dotIndicators(),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
