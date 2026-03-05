import 'dart:io';

import 'package:flutter/material.dart';
import 'package:frontend/pages/app_shell.dart';
import 'package:frontend/services/pet_store.dart';
import 'package:frontend/services/calendar_api.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  static const muted = Color(0xFF676767);

  late DateTime _selectedDay;

  final _titleCtl = TextEditingController();
  final _textCtl = TextEditingController();

  String _visibility = "shared";
  String _tag = "food";

  bool _submitting = false;
  String? _error;

  // TODO: Placeholder upload
  File? _pickedImage;

  // Day scroller settings, allow up to x days back
  static const int _dayWindow = 30;
  late final FixedExtentScrollController _dayController;

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(DateTime.now());
    _dayController = FixedExtentScrollController(
      initialItem: _dayIndexFromDate(_selectedDay).clamp(0, _dayWindow),
    );
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _textCtl.dispose();
    _dayController.dispose();
    super.dispose();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int _dayIndexFromDate(DateTime d) {
    final today = _dateOnly(DateTime.now());
    final target = _dateOnly(d);
    return today.difference(target).inDays; // 0=today, 1=yesterday, ...
  }

  DateTime _dateFromIndex(int idx) {
    final today = _dateOnly(DateTime.now());
    return today.subtract(Duration(days: idx));
  }

  String _yyyyMmDd(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-"
      "${d.month.toString().padLeft(2, '0')}-"
      "${d.day.toString().padLeft(2, '0')}";

  String _displayDay(DateTime day) => _yyyyMmDd(_dateOnly(day));

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final petId = await PetStore.getCurrentPetId();
      if (petId == null) throw "No pet selected.";

      final body = <String, dynamic>{
        "pet_id": petId,
        "entry_date": _yyyyMmDd(_dateOnly(_selectedDay)),
        "title": _titleCtl.text.trim(),
        "text": _textCtl.text.trim(),
        "photo_url": "",
        "visibility": _visibility,
        "tag": _tag,
      };

      await CalendarApi.createJournalEntry(body: body);

      if (!mounted) return;

      final popped = await Navigator.of(context).maybePop(true);
      if (!popped && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayText = _displayDay(_selectedDay);

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(""),
        backgroundColor: bg,
        foregroundColor: muted,
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
                  "Save",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _card(
                child: Row(
                  children: [
                    const Icon(Icons.event, color: muted, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      dayText,
                      style: const TextStyle(
                        fontSize: 16,
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 120,
                      height: 90,
                      child: ListWheelScrollView.useDelegate(
                        controller: _dayController,
                        itemExtent: 30,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (idx) {
                          final newDay = _dateFromIndex(idx);
                          setState(() => _selectedDay = newDay);
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _dayWindow + 1,
                          builder: (context, idx) {
                            final d = _dateFromIndex(idx);
                            final label = idx == 0
                                ? "Today"
                                : idx == 1
                                    ? "Yesterday"
                                    : _yyyyMmDd(d);
                            return Center(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Title
              _card(
                child: TextField(
                  controller: _titleCtl,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Title",
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Tag + text
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
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 170,
                      child: TextField(
                        controller: _textCtl,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Write a note…",
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Image upload + visibility
              Row(
                children: [
                  Expanded(
                    child: _card(
                      child: SizedBox(
                        height: 100,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: muted.withValues(),
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "Photo placeholder",
                            style: TextStyle(
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 140,
                    child: _card(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _visibility,
                          isExpanded: true,
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
                          onChanged: _submitting
                              ? null
                              : (v) =>
                                  setState(() => _visibility = v ?? "shared"),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (_pickedImage != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _pickedImage!,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tagChip(String value, String label) {
    final selected = _tag == value;
    return InkWell(
      onTap: _submitting ? null : () => setState(() => _tag = value),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFE7E1) : const Color(0xFFF7F5F3),
          borderRadius: BorderRadius.circular(999),
          border: selected ? Border.all(color: Colors.black, width: 1.2) : null,
        ),
        child: Text(
          label,
          style: const TextStyle(color: muted, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
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
      child: child,
    );
  }
}