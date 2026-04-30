import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend/models/pet.dart';
import 'package:frontend/services/calendar_api.dart';
import 'package:frontend/services/pet_store.dart';
import 'package:frontend/services/pets_api.dart';
import 'package:frontend/state/notifiers.dart';

class AddJournalPage extends StatefulWidget {
  final Map<String, dynamic>? entry;

  const AddJournalPage({super.key, this.entry});

  @override
  State<AddJournalPage> createState() => _AddJournalPageState();
}

class _AddJournalPageState extends State<AddJournalPage> {
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);
  static const cardBorder = Color(0xFFF0E4DB);
  static const softFill = Color(0xFFFFFCFA);
  static const chipBg = Color(0xFFF3ECE7);

  final _titleCtl = TextEditingController();
  final _textCtl = TextEditingController();
  final _newTagCtl = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  late DateTime _selectedDay;

  String _visibility = "shared";
  String _photoUrl = '';

  bool _loadingPet = true;
  bool _loadingTags = true;
  bool _submitting = false;
  bool _uploadingPhoto = false;
  bool _showAddTag = false;
  bool _creatingTag = false;
  String? _error;

  File? _pickedImage;
  List<Map<String, dynamic>> pets = [];
  List<Map<String, dynamic>> _tags = [];
  final Set<int> _selectedTagIds = {};
  Color _newTagColor = accent;

  bool get _isEditing => widget.entry != null;

  static const int _maxTags = 8;
  bool get _canAddMoreTags => _tags.length < _maxTags;

  @override
  void initState() {
    super.initState();

    final entry = widget.entry;
    if (entry != null) {
      final rawDate = (entry["entry_date"] ?? "").toString();
      DateTime parsedDate;
      try {
        parsedDate = _dateOnly(DateTime.parse(rawDate));
      } catch (_) {
        parsedDate = _dateOnly(DateTime.now());
      }

      _selectedDay = parsedDate;
      _titleCtl.text = (entry["title"] ?? "").toString();
      _textCtl.text = (entry["text"] ?? "").toString();
      _visibility = (entry["visibility"] ?? "shared").toString();
      _photoUrl = (entry["photo_url"] ?? "").toString().trim();

      final rawTags = entry["tags"];
      if (rawTags is List) {
        for (final t in rawTags) {
          if (t is Map && t["id"] is int) {
            _selectedTagIds.add(t["id"] as int);
          }
        }
      }
    } else {
      _selectedDay = _dateOnly(DateTime.now());
    }

    selectedPetNotifier.addListener(_onSelectedPetChanged);
    _init();
  }

  @override
  void dispose() {
    selectedPetNotifier.removeListener(_onSelectedPetChanged);
    _titleCtl.dispose();
    _textCtl.dispose();
    _newTagCtl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadPets();
    await _loadTags();
  }

  void _onSelectedPetChanged() {
    final selected = selectedPetNotifier.value;
    if (selected == null || !mounted) return;
    setState(() {});
    PetStore.setCurrentPetId(selected.id);
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
        _tags = List<Map<String, dynamic>>.from(tags)
          ..sort(
            (a, b) => ((a["name"] ?? "").toString()).compareTo(
              (b["name"] ?? "").toString(),
            ),
          );
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

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _yyyyMmDd(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-"
      "${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";

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

  void _toggleTag(int tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
  }

  Color _hexToColor(String? hex) {
    final cleaned = (hex ?? "").replaceAll("#", "").trim();
    if (cleaned.length != 6) return accent;
    return Color(int.parse("FF$cleaned", radix: 16));
  }

  String _colorToHex(Color color) {
    final a = (color.a * 255).round().toRadixString(16).padLeft(2, '0');
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');

    final argb = '$a$r$g$b'.toUpperCase();
    return '#${argb.substring(2)}';
  }

  Future<void> _pickDate() async {
    final today = _dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay.isAfter(today) ? today : _selectedDay,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today,
    );

    if (picked != null && mounted) {
      setState(() => _selectedDay = _dateOnly(picked));
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() {
      _pickedImage = File(image.path);
      _uploadingPhoto = true;
      _error = null;
    });

    try {
      final photoUrl = await CalendarApi.uploadJournalPhoto(
        image.path,
        mimeType: image.mimeType ?? 'image/jpeg',
      );

      if (!mounted) return;
      setState(() {
        _photoUrl = photoUrl;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _pickedImage = null;
        _photoUrl = '';
      });
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _pickedImage = null;
      _photoUrl = '';
    });
  }

  Future<void> _createTag() async {
    final name = _newTagCtl.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _creatingTag = true;
      _error = null;
    });

    try {
      final created = await CalendarApi.createJournalTag(
        name: name,
        color: _colorToHex(_newTagColor),
      );

      if (!mounted) return;
      setState(() {
        _tags = [..._tags, created]
          ..sort(
            (a, b) => ((a["name"] ?? "").toString()).compareTo(
              (b["name"] ?? "").toString(),
            ),
          );
        final id = created["id"] as int?;
        if (id != null) _selectedTagIds.add(id);
        _newTagCtl.clear();
        _showAddTag = false;
        _newTagColor = accent;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creatingTag = false);
    }
  }

  Future<void> _deleteTag(Map<String, dynamic> tag) async {
    final id = tag["id"] as int?;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete tag?"),
        content: Text('Delete "${(tag["name"] ?? "").toString()}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _error = null);

    try {
      await CalendarApi.deleteJournalTag(id);

      if (!mounted) return;
      setState(() {
        _tags.removeWhere((t) => t["id"] == id);
        _selectedTagIds.remove(id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final petId = _pet?["id"] as int?;
      if (petId == null) throw "No pet selected.";
      await PetStore.setCurrentPetId(petId);

      final body = <String, dynamic>{
        "pet_id": petId,
        "entry_date": _yyyyMmDd(_dateOnly(_selectedDay)),
        "title": _titleCtl.text.trim(),
        "text": _textCtl.text.trim(),
        "photo_url": _photoUrl,
        "visibility": _visibility,
        "tag_ids": _selectedTagIds.toList(),
      };

      final entryId = widget.entry?["id"] as int?;

      if (_isEditing && entryId != null) {
        await CalendarApi.updateJournalEntry(id: entryId, body: body);
      } else {
        await CalendarApi.createJournalEntry(body: body);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? "Journal updated." : "Journal saved."),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = _loadingPet || _loadingTags;

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed:
                isLoading || _submitting || _uploadingPhoto || _creatingTag
                ? null
                : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              disabledBackgroundColor: accent.withValues(alpha: 0.65),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isEditing ? "Save changes" : "Save journal entry",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isEditing
                          ? "Edit journal for $_petNameDisplay"
                          : "Journal entry for $_petNameDisplay",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _titleCtl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: "Title",
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: accent,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap:
                                (_submitting || _uploadingPhoto || _creatingTag)
                                ? null
                                : _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.event_outlined,
                                    size: 18,
                                    color: muted,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _yyyyMmDd(_selectedDay),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _visibility,
                              items: const [
                                DropdownMenuItem(
                                  value: "shared",
                                  child: Text("Shared"),
                                ),
                                DropdownMenuItem(
                                  value: "private",
                                  child: Text("Private"),
                                ),
                              ],
                              onChanged:
                                  (_submitting ||
                                      _uploadingPhoto ||
                                      _creatingTag)
                                  ? null
                                  : (v) => setState(
                                      () => _visibility = v ?? "shared",
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._tags.map((tag) => _tagChip(tag)),
                              if (_canAddMoreTags) _addTagButton(),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Long press a tag to delete",
                            style: TextStyle(
                              fontSize: 12,
                              color: muted.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_showAddTag) ...[
                            const SizedBox(height: 12),
                            _buildAddTagPanel(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorder),
                      ),
                      child: TextField(
                        controller: _textCtl,
                        minLines: 6,
                        maxLines: 10,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Write a quick note…",
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: (_submitting || _uploadingPhoto || _creatingTag)
                          ? null
                          : _pickAndUploadPhoto,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cardBorder),
                        ),
                        child: _pickedImage == null && _photoUrl.isEmpty
                            ? Container(
                                margin: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: softFill,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: cardBorder),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_uploadingPhoto)
                                      const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: accent,
                                      )
                                    else ...[
                                      const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: accent,
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        "Add photo",
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(17),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _pickedImage != null
                                        ? Image.file(
                                            _pickedImage!,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.network(
                                            _photoUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Container(
                                              color: chipBg,
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                              ),
                                            ),
                                          ),
                                    if (_uploadingPhoto)
                                      Container(
                                        color: Colors.black26,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: GestureDetector(
                                        onTap: _uploadingPhoto
                                            ? null
                                            : _removePhoto,
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            size: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _tagChip(Map<String, dynamic> tag) {
    final id = tag["id"] as int?;
    final name = (tag["name"] ?? "").toString();
    final color = _hexToColor(tag["color"]?.toString());
    final selected = id != null && _selectedTagIds.contains(id);

    return InkWell(
      onTap: (_submitting || _uploadingPhoto || _creatingTag || id == null)
          ? null
          : () => _toggleTag(id),
      onLongPress:
          (_submitting || _uploadingPhoto || _creatingTag || id == null)
          ? null
          : () => _deleteTag(tag),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : chipBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: selected ? color : muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addTagButton() {
    return InkWell(
      onTap: (_submitting || _uploadingPhoto || _creatingTag)
          ? null
          : () => setState(() => _showAddTag = !_showAddTag),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: softFill,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cardBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: accent),
            SizedBox(width: 6),
            Text(
              "Add",
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTagPanel() {
    final colorChoices = <Color>[
      const Color(0xFF917869),
      const Color(0xFFD88442),
      const Color(0xFFE76F51),
      const Color(0xFFF4A261),
      const Color(0xFF2A9D8F),
      const Color(0xFF457B9D),
      const Color(0xFF8D99AE),
      const Color(0xFFB56576),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _newTagCtl,
            decoration: InputDecoration(
              hintText: "Tag name",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: colorChoices.map((color) {
              final selected = _newTagColor.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _newTagColor = color),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.black87 : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: _creatingTag
                    ? null
                    : () {
                        _newTagCtl.clear();
                        setState(() {
                          _showAddTag = false;
                          _newTagColor = accent;
                        });
                      },
                child: const Text("Cancel"),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _creatingTag ? null : _createTag,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _creatingTag
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Save tag",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
      ),
      child: child,
    );
  }
}
