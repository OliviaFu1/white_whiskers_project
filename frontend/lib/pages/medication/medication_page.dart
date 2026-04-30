import 'package:flutter/material.dart';
import 'package:frontend/models/pet.dart';
import 'package:frontend/services/medication_api.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/state/notifiers.dart';
import 'package:frontend/services/pet_store.dart';
import 'medication_detail_page.dart';
import 'medication_form_page.dart';

class MedicationPage extends StatefulWidget {
  final DateTime? initialDate;
  const MedicationPage({super.key, this.initialDate});

  @override
  State<MedicationPage> createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  static const bg = Color(0xFFFBF2EB);
  static const titleColor = Color(0xFFD88442);
  static const accent = Color(0xFF917869);
  static const muted = Color(0xFF676767);

  List<Map<String, dynamic>> _allMedications = [];
  bool _loading = true;
  String? _error;
  int? _petId;
  String _petName = "your pet";

  late DateTime _selectedDate;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(widget.initialDate ?? DateTime.now());
    _load();
  }

  Future<void> _load({Pet? pet}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resolvedPet = pet ?? selectedPetNotifier.value;
      final petId = resolvedPet?.id ?? await PetStore.getCurrentPetId();
      if (petId == null) throw "No pet selected.";
      _petId = petId;
      _petName = resolvedPet?.name ?? "your pet";
      final meds = await MedicationApi.listMedications(petId: petId);
      if (!mounted) return;
      for (final med in meds) {
        try {
          await NotificationService.syncFromMedication(med, _petName);
        } catch (_) {}
      }
      setState(() => _allMedications = meds);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  bool _isDueOnDate(Map<String, dynamic> med, DateTime date) {
    if ((med["status"] ?? "") != "active") return false;
    if (med["as_needed"] == true) return false;

    final startStr = med["start_date"]?.toString() ?? "";
    if (startStr.isEmpty) return false;
    final start = _dateOnly(DateTime.parse(startStr));
    if (date.isBefore(start)) return false;

    final endStr = med["end_date"]?.toString();
    if (endStr != null && endStr.isNotEmpty) {
      final end = _dateOnly(DateTime.parse(endStr));
      if (date.isAfter(end)) return false;
    }

    final schedules =
        (med["schedules"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    for (final s in schedules) {
      if (s["active"] == false) continue;
      final type = s["schedule_type"] as String? ?? "";
      if (type == "fixed_times" || type == "interval") return true;
      if (type == "weekly") {
        final days =
            (s["days_of_week"] as List?)?.cast<String>() ?? [];
        if (days.contains(_weekdayAbbr(date.weekday))) return true;
      }
    }
    return false;
  }

  static String _weekdayAbbr(int weekday) {
    const map = {
      1: "mon",
      2: "tue",
      3: "wed",
      4: "thu",
      5: "fri",
      6: "sat",
      7: "sun",
    };
    return map[weekday] ?? "";
  }

  List<Map<String, dynamic>> get _medsForDay =>
      _allMedications.where((m) => _isDueOnDate(m, _selectedDate)).toList();

  List<Map<String, dynamic>> get _prnMeds => _allMedications
      .where((m) =>
          (m["status"] ?? "") == "active" && m["as_needed"] == true)
      .toList();

  // ── Helpers ─────────────────────────────────────────────────────────────

  String _fmtNum(dynamic v) {
    if (v == null) return "";
    final d = double.tryParse(v.toString());
    if (d == null) return v.toString();
    return d.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _singularUnit(String unit) {
    final lower = unit.toLowerCase();
    if (lower == "ml" || !lower.endsWith('s')) return unit;
    return unit.substring(0, unit.length - 1);
  }

  String _formatDisplayDate(DateTime d) {
    const months = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December",
    ];
    final today = _dateOnly(DateTime.now());
    if (d == today) return "Today, ${months[d.month - 1]} ${d.day}";
    final yesterday = _dateOnly(today.subtract(const Duration(days: 1)));
    if (d == yesterday) {
      return "Yesterday, ${months[d.month - 1]} ${d.day}";
    }
    final tomorrow = _dateOnly(today.add(const Duration(days: 1)));
    if (d == tomorrow) {
      return "Tomorrow, ${months[d.month - 1]} ${d.day}";
    }
    return "${months[d.month - 1]} ${d.day}, ${d.year}";
  }

  /// Expands the medications due on the selected day into individual dose
  /// entries — one per scheduled time — sorted chronologically.
  List<({Map<String, dynamic> med, String timeLabel, int sortMinutes})>
      get _doseEntries {
    final entries =
        <({Map<String, dynamic> med, String timeLabel, int sortMinutes})>[];

    for (final med in _medsForDay) {
      final schedules =
          (med["schedules"] as List?)?.cast<Map<String, dynamic>>() ?? [];
      bool added = false;

      for (final s in schedules) {
        if (s["active"] == false) continue;
        final type = s["schedule_type"] as String? ?? "";

        final t = s["time_of_day"]?.toString() ?? "";
        if (t.isNotEmpty) {
          final parts = t.split(":");
          if (parts.length >= 2) {
            final h = int.tryParse(parts[0]) ?? 0;
            final m = int.tryParse(parts[1]) ?? 0;
            final ap = h >= 12 ? "PM" : "AM";
            final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
            final label = "$h12:${m.toString().padLeft(2, '0')} $ap";
            entries.add((med: med, timeLabel: label, sortMinutes: h * 60 + m));
            added = true;
            continue;
          }
        }

        // No clock time — one fallback entry per medication
        if (!added) {
          String label = "";
          if (type == "interval") {
            final h = (s["interval_hours"] as int?) ?? 0;
            label = (h > 0 && h % 24 == 0)
                ? "Every ${h ~/ 24} day${h ~/ 24 == 1 ? '' : 's'}"
                : "Every ${h}h";
          } else if (type == "weekly") {
            const dayOrder = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
            final days = ((s["days_of_week"] as List?)?.cast<String>() ?? [])
                .toList()..sort((a, b) => dayOrder.indexOf(a).compareTo(dayOrder.indexOf(b)));
            label = days.isEmpty ? "Weekly" : days.join(", ");
          }
          entries.add((
            med: med,
            timeLabel: label,
            sortMinutes: 9999,
          ));
          added = true;
        }
      }

      if (!added) {
        entries.add((med: med, timeLabel: "", sortMinutes: 9999));
      }
    }

    entries.sort((a, b) => a.sortMinutes.compareTo(b.sortMinutes));
    return entries;
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: const BackButton(color: muted),
        title: const Text(
          "Medication Schedule",
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_petId != null)
            IconButton(
              icon: const Icon(Icons.add, color: accent),
              tooltip: "Add medication",
              onPressed: _handleAdd,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    _petChipRow(),
                    const Divider(height: 1, color: Color(0xFFE5DDD6)),
                    _dateNavRow(),
                    const Divider(height: 1, color: Color(0xFFE5DDD6)),
                    Expanded(child: _body()),
                  ],
                ),
    );
  }

  Widget _petChipRow() {
    final pets = petsNotifier.value.where((p) => p.isDeceased != true).toList();
    if (pets.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: pets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final pet = pets[i];
          final selected = pet.id == _petId;
          return ChoiceChip(
            label: Text(pet.name),
            selected: selected,
            selectedColor: const Color(0xFFD88442).withValues(alpha: 0.15),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              color: selected ? const Color(0xFFD88442) : const Color(0xFF676767),
            ),
            side: BorderSide(
              color: selected
                  ? const Color(0xFFD88442).withValues(alpha: 0.4)
                  : const Color(0xFFDDD5CE),
            ),
            backgroundColor: Colors.white,
            onSelected: (_) {
              if (!selected) _load(pet: pet);
            },
          );
        },
      ),
    );
  }

  Widget _dateNavRow() {
    final today = _dateOnly(DateTime.now());
    final isToday = _selectedDate == today;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: muted),
            onPressed: () => setState(() {
              _selectedDate = _dateOnly(
                  _selectedDate.subtract(const Duration(days: 1)));
            }),
          ),
          Expanded(
            child: Text(
              _formatDisplayDate(_selectedDate),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: muted),
            onPressed: () => setState(() {
              _selectedDate =
                  _dateOnly(_selectedDate.add(const Duration(days: 1)));
            }),
          ),
          AnimatedOpacity(
            opacity: isToday ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: TextButton(
              onPressed: isToday
                  ? null
                  : () => setState(() => _selectedDate = today),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                "Today",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final prn = _prnMeds;

    if (_doseEntries.isEmpty && prn.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.medication_outlined, size: 56, color: muted),
              const SizedBox(height: 16),
              const Text(
                "No medications scheduled",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: muted),
              ),
              const SizedBox(height: 8),
              const Text(
                "Nothing is due on this day.",
                style: TextStyle(fontSize: 14, color: muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_allMedications.isEmpty)
                TextButton.icon(
                  onPressed: _handleAdd,
                  icon: const Icon(Icons.add, color: accent),
                  label: const Text(
                    "Add first medication",
                    style: TextStyle(color: accent),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final doses = _doseEntries;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          if (doses.isNotEmpty) ...[
            _sectionHeader("Scheduled"),
            ...doses.map((e) => _scheduleCard(e.med, e.timeLabel)),
          ],
          if (prn.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionHeader("As Needed"),
            ...prn.map((m) => _scheduleCard(m, "PRN")),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _openDetail(Map<String, dynamic> med) async {
    if (_petId == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationDetailPage(
          medication: med,
          petId: _petId!,
          petName: _petName,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Widget _scheduleCard(Map<String, dynamic> med, String timeLabel) {
    final drugName = (med["drug_name"] ?? "").toString();
    final doseAmount = _fmtNum(med["dose_amount"]);
    final doseUnit = (med["dose_unit"] ?? "").toString();
    final sigText = (med["sig_text"] ?? "").toString();
    final asNeeded = med["as_needed"] == true;
    final withFood = med["with_food"];
    final displayLabel = timeLabel.isEmpty ? "—" : timeLabel;

    return GestureDetector(
      onTap: () => _openDetail(med),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              blurRadius: 6,
              offset: Offset(0, 3),
              color: Color(0x14000000),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: asNeeded
                      ? const Color(0xFFF2D3B8)
                      : const Color(0xFFE8E0D8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  displayLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: displayLabel.length > 6 ? 10 : 13,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drugName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                    if (doseAmount.isNotEmpty || doseUnit.isNotEmpty)
                      Text(
                        "$doseAmount ${doseAmount == "1" ? _singularUnit(doseUnit) : doseUnit}".trim(),
                        style: const TextStyle(fontSize: 13, color: muted),
                      ),
                    if (sigText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        sigText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF999999),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (withFood == true) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: const [
                          Icon(Icons.restaurant_outlined,
                              size: 12, color: accent),
                          SizedBox(width: 3),
                          Text(
                            "Give with food",
                            style: TextStyle(fontSize: 11, color: accent),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAdd() async {
    if (_petId == null) return;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => MedicationFormPage(
          petId: _petId!,
          petName: _petName,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _load();
  }
}
