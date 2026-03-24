import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend/pages/app_shell.dart';
import 'package:frontend/services/calendar_api.dart';
import 'package:frontend/services/pet_store.dart';
import 'package:frontend/services/pets_api.dart';
import 'package:frontend/state/notifiers.dart';
import 'package:frontend/models/pet.dart';

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
  static const softFill = Color(0xFFFFFCFA);
  static const chipBg = Color(0xFFF3ECE7);

  final _titleCtl = TextEditingController();
  final _textCtl = TextEditingController();
  final _manualTagCtl = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  late DateTime _selectedDay;

  String _visibility = "shared";
  String _tag = "food";
  String _photoUrl = '';

  bool _loadingPet = true;
  bool _submitting = false;
  bool _uploadingPhoto = false;
  String? _error;

  File? _pickedImage;
  List<Map<String, dynamic>> pets = [];

  void _onSelectedPetChanged() {
    final selected = selectedPetNotifier.value;
    if (selected == null || !mounted) return;
    setState(() {});
    PetStore.setCurrentPetId(selected.id);
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(DateTime.now());
    _loadPets();
    selectedPetNotifier.addListener(_onSelectedPetChanged);
  }

  @override
  void dispose() {
    selectedPetNotifier.removeListener(_onSelectedPetChanged);
    _titleCtl.dispose();
    _textCtl.dispose();
    _manualTagCtl.dispose();
    super.dispose();
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

  String get _finalTag {
    final manual = _manualTagCtl.text.trim();
    return manual.isNotEmpty ? manual : _tag;
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

      setState(() {
        _photoUrl = photoUrl;
      });
    } catch (e) {
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
        "tag": _finalTag,
      };

      await CalendarApi.createJournalEntry(body: body);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Journal saved.")));

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _loadingPet || _submitting || _uploadingPhoto
                ? null
                : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              disabledBackgroundColor: accent.withOpacity(0.65),
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
                : const Text(
                    "Save journal entry",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: _loadingPet
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Journal entry for $_petNameDisplay",
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
                            onTap: (_submitting || _uploadingPhoto)
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
                              onChanged: (_submitting || _uploadingPhoto)
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
                              _tagChip("food", "Food"),
                              _tagChip("sleep", "Sleep"),
                              _tagChip("med", "Med"),
                              _tagChip("symptoms", "Symptoms"),
                              _tagChip("mood", "Mood"),
                              _tagChip("activity", "Activity"),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _manualTagCtl,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: "Add your own tag",
                              filled: true,
                              fillColor: softFill,
                              prefixIcon: const Icon(
                                Icons.sell_outlined,
                                color: muted,
                                size: 18,
                              ),
                              suffixIcon: _manualTagCtl.text.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _manualTagCtl.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
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
                      onTap: (_submitting || _uploadingPhoto)
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
                        child: _pickedImage == null
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
                                    Image.file(
                                      _pickedImage!,
                                      fit: BoxFit.cover,
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

  Widget _tagChip(String value, String label) {
    final selected = _tag == value && _manualTagCtl.text.trim().isEmpty;

    return InkWell(
      onTap: (_submitting || _uploadingPhoto)
          ? null
          : () {
              _manualTagCtl.clear();
              setState(() => _tag = value);
            },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8DDD5) : chipBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : muted,
            fontWeight: FontWeight.w700,
          ),
        ),
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
