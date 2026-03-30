import 'package:flutter/material.dart';

import 'package:frontend/models/pet.dart';
import 'package:frontend/pages/main_pages/add_journal_page.dart';
import 'package:frontend/services/calendar_api.dart';
import 'package:frontend/services/pet_store.dart';
import 'package:frontend/services/pets_api.dart';
import 'package:frontend/state/notifiers.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);
  static const cardBorder = Color(0xFFF0E4DB);
  static const chipBg = Color(0xFFF3ECE7);

  bool _loadingPet = true;
  bool _loadingEntries = true;
  bool _loadingTags = true;
  String? _error;

  List<Map<String, dynamic>> pets = [];
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _tags = [];

  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    selectedPetNotifier.addListener(_onSelectedPetChanged);
    _init();
  }

  @override
  void dispose() {
    selectedPetNotifier.removeListener(_onSelectedPetChanged);
    super.dispose();
  }

  Future<void> _init() async {
    await _loadPets();
    await Future.wait([_loadTags(), _loadEntries()]);
  }

  void _onSelectedPetChanged() {
    final selected = selectedPetNotifier.value;
    if (selected == null || !mounted) return;
    PetStore.setCurrentPetId(selected.id);
    setState(() {});
    _loadEntries();
  }

  Future<void> _loadPets() async {
    try {
      final petList = await PetsApi.listPets();

      final petModels = petList
          .map(
            (p) => Pet(
              id: p["id"] as int,
              name: (p["name"] ?? "").toString(),
              photoUrl: p["photo_url"]?.toString(),
            ),
          )
          .toList();

      petsNotifier.value = petModels;

      final currentId = selectedPetNotifier.value?.id;
      final refreshed = currentId != null
          ? petModels.where((p) => p.id == currentId).firstOrNull
          : null;

      if (refreshed != null) {
        selectedPetNotifier.value = refreshed;
        await PetStore.setCurrentPetId(refreshed.id);
      } else if (petModels.isNotEmpty) {
        selectedPetNotifier.value = petModels.first;
        await PetStore.setCurrentPetId(petModels.first.id);
      }

      if (!mounted) return;
      setState(() {
        pets = petList;
        _loadingPet = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingPet = false;
      });
    }
  }

  Future<void> _loadTags() async {
    try {
      final tags = await CalendarApi.listJournalTags();
      if (!mounted) return;
      setState(() {
        _tags = tags;
        _loadingTags = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTags = false;
      });
    }
  }

  Future<void> _loadEntries() async {
    final petId = _pet?["id"] as int?;
    if (petId == null) {
      if (!mounted) return;
      setState(() {
        _entries = [];
        _loadingEntries = false;
      });
      return;
    }

    setState(() {
      _loadingEntries = true;
      _error = null;
    });

    try {
      final entries = await CalendarApi.listJournalEntries(
        petId: petId,
        tag: _selectedTag,
      );

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loadingEntries = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingEntries = false;
      });
    }
  }

  Map<String, dynamic>? get _pet {
    if (pets.isEmpty) return null;

    final selectedId = selectedPetNotifier.value?.id;
    if (selectedId == null) return pets.first;

    return pets.firstWhere(
      (p) => (p["id"] as int?) == selectedId,
      orElse: () => pets.first,
    );
  }

  String get _petNameDisplay {
    final name = (_pet?["name"] ?? "").toString().trim();
    return name.isEmpty ? "Your Pet" : name;
  }

  Future<void> _openAddPage() async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddJournalPage()));

    await Future.wait([_loadTags(), _loadEntries()]);
  }

  String _formatDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return "${d.year}-$mm-$dd";
    } catch (_) {
      return raw;
    }
  }

  Color _parseHexColor(String? hex, {Color fallback = chipBg}) {
    if (hex == null) return fallback;
    final cleaned = hex.trim().replaceFirst('#', '');
    if (cleaned.length != 6) return fallback;

    try {
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  List<Map<String, dynamic>> _normalizedTags(dynamic rawTags) {
    if (rawTags is! List) return const [];

    return rawTags
        .whereType<dynamic>()
        .map((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        })
        .where((e) => (e["name"] ?? "").toString().trim().isNotEmpty)
        .toList();
  }

  String _authorDisplay(Map<String, dynamic> entry) {
    final author = entry["author"];

    if (author is Map) {
      final first = (author["first_name"] ?? "").toString().trim();
      final last = (author["last_name"] ?? "").toString().trim();
      final full = "$first $last".trim();
      if (full.isNotEmpty) return full;

      final username = (author["username"] ?? "").toString().trim();
      if (username.isNotEmpty) return username;

      final name = (author["name"] ?? "").toString().trim();
      if (name.isNotEmpty) return name;
    }

    final authorName = (entry["author_name"] ?? "").toString().trim();
    if (authorName.isNotEmpty) return authorName;

    return "Unknown author";
  }

  String _entryPreview(Map<String, dynamic> entry) {
    final text = (entry["text"] ?? "").toString().trim();
    if (text.isNotEmpty) return text;

    final tags = _normalizedTags(entry["tags"]);
    if (tags.isNotEmpty) {
      return tags.map((tag) => "#${tag["name"]}").join("  ");
    }

    return "No details added";
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _loadingPet || _loadingTags;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          "Journal for $_petNameDisplay",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: _openAddPage,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                          ),
                          child: const Icon(Icons.add, color: accent, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildTagFilters(),
                  const SizedBox(height: 14),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (_loadingEntries)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_entries.isEmpty)
                    _buildEmptyState()
                  else
                    ..._entries.map(_buildEntryCard),
                ],
              ),
      ),
    );
  }

  Widget _buildTagFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _selectedTag = null);
              _loadEntries();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: _selectedTag == null
                    ? accent.withValues(alpha: 0.15)
                    : chipBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _selectedTag == null ? accent : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Text(
                "All",
                style: TextStyle(
                  color: _selectedTag == null ? accent : muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          ..._tags.map((tag) {
            final name = (tag["name"] ?? "").toString().trim();
            final selected = _selectedTag == name;
            final color = _parseHexColor(tag["color"]?.toString());

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedTag = name);
                  _loadEntries();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.18)
                        : color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected ? color : color.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.menu_book_outlined, size: 34, color: accent),
          const SizedBox(height: 10),
          const Text(
            "No journal entries yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Tap the + button to add one for $_petNameDisplay.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final title = (entry["title"] ?? "").toString().trim();
    final displayTitle = title.isEmpty ? "Untitled entry" : title;

    final date = _formatDate((entry["entry_date"] ?? "").toString());
    final photoUrl = (entry["photo_url"] ?? "").toString().trim();

    final author = _authorDisplay(entry);

    // --- normalize tags (important: backend now returns objects)
    final rawTags = entry["tags"];
    final tags = (rawTags is List)
        ? rawTags
              .whereType<dynamic>()
              .map((e) {
                if (e is Map<String, dynamic>) return e;
                if (e is Map) return Map<String, dynamic>.from(e);
                return <String, dynamic>{};
              })
              .where((e) => (e["name"] ?? "").toString().trim().isNotEmpty)
              .toList()
        : <Map<String, dynamic>>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- LEFT CONTENT ---
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TITLE ---
                Text(
                  displayTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 4),

                // --- DATE + AUTHOR (same row) ---
                Row(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        "By $author",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                // --- TAGS ---
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((tag) {
                      final name = (tag["name"] ?? "").toString().trim();

                      final color = _parseHexColor(tag["color"]?.toString());

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: color.withValues(alpha: 0.7),
                            width: 1.3,
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 10),

                // --- PREVIEW TEXT ---
                Text(
                  _entryPreview(entry),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: muted,
                    height: 1.35,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // --- IMAGE ---
          if (photoUrl.isNotEmpty) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                photoUrl,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 84,
                  height: 84,
                  color: chipBg,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
