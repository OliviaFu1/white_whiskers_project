import 'package:flutter/material.dart';
import '../../services/medication_api.dart';
import '../../services/notification_service.dart';
import 'medication_form_page.dart';
import 'medication_log_page.dart';
import 'prescription_supply_page.dart';

class MedicationDetailPage extends StatefulWidget {
  final Map<String, dynamic> medication;
  final int petId;
  final String petName;

  const MedicationDetailPage({
    super.key,
    required this.medication,
    required this.petId,
    required this.petName,
  });

  @override
  State<MedicationDetailPage> createState() => _MedicationDetailPageState();
}

class _MedicationDetailPageState extends State<MedicationDetailPage> {
  static const bg = Color(0xFFFBF2EB);
  static const titleColor = Color(0xFFD88442);
  static const accent = Color(0xFF917869);
  static const muted = Color(0xFF676767);

  late Map<String, dynamic> _med;
  bool _updatingStatus = false;
  String _pendingLogNotes = "";

  @override
  void initState() {
    super.initState();
    _med = widget.medication;
  }

  @override
  Widget build(BuildContext context) {
    final drugName = (_med["drug_name"] ?? "").toString();
    final status = (_med["status"] ?? "active").toString();
    final form = (_med["form"] ?? "").toString();
    final route = (_med["route"] ?? "").toString();
    final formDescription = (_med["form_description"] ?? "").toString();
    final doseAmount = _fmtNum(_med["dose_amount"]);
    final doseUnit = (_med["dose_unit"] ?? "").toString();
    final sigText = (_med["sig_text"] ?? "").toString();
    final startDate = (_med["start_date"] ?? "").toString();
    final vetName = (_med["prescribing_vet_name"] ?? "").toString();
    final vetClinic = (_med["prescribing_vet_clinic"] ?? "").toString();
    final withFood = _med["with_food"];
    final asNeeded = _med["as_needed"] == true;
    final schedules =
        (_med["schedules"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final prescriptions =
        (_med["prescriptions"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final prescription = prescriptions.isNotEmpty ? prescriptions.first : null;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: const BackButton(color: muted),
        title: Text(
          drugName,
          style: const TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: muted),
            tooltip: "History",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MedicationLogPage(
                  medicationId: _med["id"] as int,
                  drugName: _med["drug_name"] as String,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    drugName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: muted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _updatingStatus ? null : () => _pickStatus(status),
                  child: _statusBadge(status),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailCard([
              _detailRow("Type", _typeLabel(form, route, formDescription)),
              _detailRow(
                "Dose",
                "$doseAmount ${doseAmount == "1" ? _singularUnit(doseUnit) : doseUnit}"
                    .trim(),
              ),
              _detailRow("Instructions", sigText),
            ]),
            const SizedBox(height: 14),
            _detailCard([
              _detailRow(
                "Start date",
                startDate.isNotEmpty ? _formatDate(startDate) : "—",
              ),
              _detailRow(
                "Schedule",
                asNeeded ? "As needed (PRN)" : _scheduleSummary(schedules),
              ),
            ]),
            const SizedBox(height: 14),
            _detailCard([
              _detailRow("Prescribing vet", vetName.isNotEmpty ? vetName : "—"),
              if (vetClinic.isNotEmpty) _detailRow("Clinic", vetClinic),
              _detailRow(
                "Give with food",
                withFood == true
                    ? "Yes"
                    : withFood == false
                    ? "No"
                    : "Not specified",
              ),
            ]),
            if (prescription != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.of(context)
                      .push<Map<String, dynamic>>(
                        MaterialPageRoute(
                          builder: (_) => PrescriptionSupplyPage(
                            prescription: prescription,
                            medication: _med,
                            drugName: drugName,
                          ),
                        ),
                      );
                  if (result == null || !mounted) return;
                  final updatedRx =
                      result["rx"] as Map<String, dynamic>? ?? result;
                  final updatedMedFields =
                      result["med"] as Map<String, dynamic>?;
                  setState(() {
                    final prescriptions =
                        (_med["prescriptions"] as List?)
                            ?.cast<Map<String, dynamic>>() ??
                        [];
                    final idx = prescriptions.indexWhere(
                      (p) => p["id"] == updatedRx["id"],
                    );
                    final updatedPrescriptions =
                        List<Map<String, dynamic>>.from(prescriptions);
                    if (idx >= 0) updatedPrescriptions[idx] = updatedRx;
                    _med = {
                      ..._med,
                      if (updatedMedFields != null) ...updatedMedFields,
                      "prescriptions": updatedPrescriptions,
                    };
                  });
                },
                child: _supplyCard(prescription),
              ),
            ],

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text(
                  "Edit medication",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: _handleEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supplyCard(Map<String, dynamic> rx) {
    final remaining = rx["quantity_remaining"];
    final unit = (rx["quantity_unit"] ?? "").toString();
    final expirationStr = (rx["expiration_date"] ?? "").toString();
    final refillsAuthorized = (rx["refills_authorized"] as int?) ?? 0;
    final refillsUsed = (rx["refills_used"] as int?) ?? 0;
    final refillsLeft = refillsAuthorized - refillsUsed;

    String remainingText = "—";
    if (remaining != null) {
      final val = double.tryParse(remaining.toString());
      if (val != null) {
        final numStr = val
            .toStringAsFixed(4)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
        remainingText = unit.isNotEmpty ? "$numStr $unit" : numStr;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 4),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Prescription supply",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFFBBB3AC),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _supplyTile(
                icon: Icons.medication_outlined,
                label: "Remaining",
                value: remainingText,
              ),
              _supplyDivider(),
              _supplyTile(
                icon: Icons.event_outlined,
                label: "Expected end",
                value: expirationStr.isNotEmpty
                    ? _formatDate(expirationStr)
                    : "—",
              ),
              _supplyDivider(),
              _supplyTile(
                icon: Icons.refresh,
                label: "Refills left",
                value: refillsLeft.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _supplyTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _supplyDivider() =>
      Container(width: 1, height: 48, color: const Color(0xFFEEE8E3));

  Widget _detailCard(List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 4),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "—" : value,
              style: const TextStyle(fontSize: 14, color: muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (label, color) = switch (status) {
      "active" => ("Active", const Color(0xFF4CAF50)),
      "paused" => ("Paused", const Color(0xFFFF9800)),
      "stopped" => ("Stopped", const Color(0xFFE53935)),
      "completed" => ("Completed", const Color(0xFF2196F3)),
      _ => (status, muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _scheduleSummary(List<Map<String, dynamic>> schedules) {
    if (schedules.isEmpty) return "—";
    final s = schedules.first;
    final type = s["schedule_type"] as String? ?? "";
    switch (type) {
      case "fixed_times":
        final t = s["time_of_day"]?.toString() ?? "";
        if (t.isNotEmpty) {
          final parts = t.split(":");
          if (parts.length >= 2) {
            final h = int.tryParse(parts[0]) ?? 0;
            final min = parts[1].padLeft(2, '0');
            final ap = h >= 12 ? "PM" : "AM";
            final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
            return "Daily at $h12:$min $ap";
          }
        }
        return "Daily";
      case "interval":
        final h = s["interval_hours"] as int? ?? 0;
        if (h > 0 && h % 24 == 0)
          return "Every ${h ~/ 24} day${h ~/ 24 == 1 ? '' : 's'}";
        return "Every ${h}h";
      case "weekly":
        const dayOrder = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
        final days = ((s["days_of_week"] as List?)?.cast<String>() ?? [])
            .toList()..sort((a, b) => dayOrder.indexOf(a).compareTo(dayOrder.indexOf(b)));
        return days.isEmpty ? "Weekly" : days.map(_capitalize).join(", ");
      default:
        return "—";
    }
  }

  String _fmtNum(dynamic v) {
    if (v == null) return "";
    final d = double.tryParse(v.toString());
    if (d == null) return v.toString();
    return d
        .toStringAsFixed(4)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _singularUnit(String unit) {
    final lower = unit.toLowerCase();
    if (lower == "ml" || !lower.endsWith('s')) return unit;
    return unit.substring(0, unit.length - 1);
  }

  String _typeLabel(String form, String route, String formDescription) {
    const map = {
      ("tablet", "oral"): "Tablet",
      ("capsule", "oral"): "Capsule",
      ("liquid", "oral"): "Liquid (oral)",
      ("liquid", "ophthalmic"): "Drops",
      ("liquid", "otic"): "Drops",
      ("injection", "injectable"): "Injection",
      ("topical", "topical"): "Topical",
      ("other", "inhaled"): "Inhaler",
    };
    final label = map[(form, route)];
    if (label != null) return label;
    // "other" with a custom description
    if (formDescription.isNotEmpty) return formDescription;
    // Fallback: show both capitalized
    if (form.isNotEmpty && route.isNotEmpty) {
      return "${_capitalize(form)} · ${_capitalize(route)}";
    }
    return _capitalize(form.isNotEmpty ? form : route);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  double? _calcRemainingAt(DateTime pauseDate) {
    final prescriptions =
        (_med["prescriptions"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (prescriptions.isEmpty) return null;
    final rx = prescriptions.first;

    final currentRemaining = double.tryParse(
      rx["quantity_remaining"]?.toString() ?? "",
    );
    // Use prescription's dose snapshot, fall back to medication's dose.
    final dose =
        double.tryParse(rx["dose_amount"]?.toString() ?? "") ??
        double.tryParse(_med["dose_amount"]?.toString() ?? "");
    if (currentRemaining == null || dose == null || dose <= 0) return null;

    if (_med["as_needed"] == true) return null;

    final schedules =
        (_med["schedules"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (schedules.isEmpty) return null;

    // Date range: pauseDate (inclusive) up to but not including today.
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final pauseDay = DateTime(pauseDate.year, pauseDate.month, pauseDate.day);
    final daysNotTaken = todayOnly.difference(pauseDay).inDays;
    if (daysNotTaken <= 0) return null;

    final type = (schedules.first["schedule_type"] as String?) ?? "";
    double addBack;
    switch (type) {
      case "fixed_times":
        final timesPerDay = schedules
            .where((s) => s["schedule_type"] == "fixed_times")
            .length;
        addBack = daysNotTaken * (timesPerDay > 0 ? timesPerDay : 1) * dose;
      case "interval":
        final hours =
            int.tryParse(schedules.first["interval_hours"]?.toString() ?? "") ??
            0;
        if (hours <= 0) return null;
        // Round to nearest whole dose to avoid irrational decimals.
        final totalDoses = (daysNotTaken * 24 / hours).round();
        addBack = totalDoses * dose;
      case "weekly":
        // Count actual scheduled weekdays in the missed range instead of averaging.
        const dayMap = {
          "mon": DateTime.monday,
          "tue": DateTime.tuesday,
          "wed": DateTime.wednesday,
          "thu": DateTime.thursday,
          "fri": DateTime.friday,
          "sat": DateTime.saturday,
          "sun": DateTime.sunday,
        };
        final scheduledWeekdays =
            (schedules.first["days_of_week"] as List?)
                ?.cast<String>()
                .map((d) => dayMap[d.toLowerCase()])
                .whereType<int>()
                .toSet() ??
            {};
        if (scheduledWeekdays.isEmpty) return null;
        final timesPerDay = schedules
            .where((s) => s["schedule_type"] == "weekly")
            .length;
        int missedDays = 0;
        for (int i = 0; i < daysNotTaken; i++) {
          if (scheduledWeekdays.contains(
            pauseDay.add(Duration(days: i)).weekday,
          )) {
            missedDays++;
          }
        }
        addBack = missedDays * (timesPerDay > 0 ? timesPerDay : 1) * dose;
      default:
        return null;
    }

    final result = (currentRemaining + addBack).clamp(0.0, double.infinity);
    // Round to 4 decimal places to match backend DecimalField(max_digits=10, decimal_places=4).
    return double.parse(result.toStringAsFixed(4));
  }

  Future<void> _pickStatus(String current) async {
    const statuses = [
      ("active", "Active", Color(0xFF4CAF50)),
      ("paused", "Paused", Color(0xFFFF9800)),
      ("stopped", "Stopped", Color(0xFFE53935)),
      ("completed", "Completed", Color(0xFF2196F3)),
    ];

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 20, 22, 8),
              child: Text(
                "Change status",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
            ),
            ...statuses.map((s) {
              final isSelected = s.$1 == current;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 2,
                ),
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: s.$3,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  s.$2,
                  style: TextStyle(
                    fontSize: 16,
                    color: muted,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: muted, size: 20)
                    : null,
                onTap: () => Navigator.of(ctx).pop(s.$1),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || picked == current || !mounted) return;

    // For pause/stop, ask when it happened and recalculate supply.
    double? newRemaining;
    DateTime? pickedDate;
    if (picked == "paused" || picked == "stopped") {
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      DateTime firstDate;
      try {
        final s = DateTime.parse((_med["start_date"] ?? "").toString());
        firstDate = DateTime(s.year, s.month, s.day);
      } catch (_) {
        firstDate = DateTime(2000);
      }

      pickedDate = await showDatePicker(
        context: context,
        helpText: picked == "paused"
            ? "When did you pause this medication?"
            : "When did you stop this medication?",
        initialDate: todayOnly,
        firstDate: firstDate,
        lastDate: todayOnly,
      );
      if (!mounted) return;
      if (pickedDate == null) return;

      newRemaining = _calcRemainingAt(pickedDate);

      // Ask for optional notes on why they paused/stopped
      final notesController = TextEditingController();
      final notesInput = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: bg,
          title: Text(
            picked == "paused" ? "Reason for pausing?" : "Reason for stopping?",
            style: const TextStyle(
              color: muted,
              fontWeight: FontWeight.w700,
              fontSize: 17,
            ),
          ),
          content: TextField(
            controller: notesController,
            autofocus: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: "Optional note…",
              hintStyle: const TextStyle(color: Color(0xFFBBB3AC)),
              filled: true,
              fillColor: const Color(0xFFF5EDE6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(""),
              child: const Text("Skip", style: TextStyle(color: muted)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(notesController.text.trim()),
              child: const Text(
                "Save",
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      final logNotes = notesInput ?? "";

      // Store for use in the PATCH body below
      _pendingLogNotes = logNotes;
    }

    setState(() => _updatingStatus = true);
    try {
      final body = <String, dynamic>{"status": picked};
      if (pickedDate != null) {
        body["event_date"] =
            "${pickedDate.year.toString().padLeft(4, '0')}-"
            "${pickedDate.month.toString().padLeft(2, '0')}-"
            "${pickedDate.day.toString().padLeft(2, '0')}";
        if (_pendingLogNotes.isNotEmpty) body["log_notes"] = _pendingLogNotes;
        _pendingLogNotes = "";
      }
      final updated = await MedicationApi.updateMedication(
        id: _med["id"] as int,
        body: body,
      );
      if (!mounted) return;

      var prescriptions =
          (_med["prescriptions"] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (newRemaining != null && prescriptions.isNotEmpty) {
        final rxId = prescriptions.first["id"] as int?;
        if (rxId != null) {
          final updatedRx = await MedicationApi.updatePrescription(
            prescriptionId: rxId,
            body: {"quantity_remaining": newRemaining},
          );
          if (mounted) prescriptions = [updatedRx, ...prescriptions.skip(1)];
        }
      }

      if (!mounted) return;
      setState(() => _med = {...updated, "prescriptions": prescriptions});
      await NotificationService.syncFromMedication(updated, widget.petName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _handleEdit() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => MedicationFormPage(
          petId: widget.petId,
          petName: widget.petName,
          medication: _med,
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result["__deleted"] == true) {
      Navigator.of(context).pop(result);
      return;
    }
    final returnedRx = result["prescriptions"] as List?;
    setState(
      () => _med = {
        ...result,
        "prescriptions": (returnedRx != null && returnedRx.isNotEmpty)
            ? returnedRx
            : _med["prescriptions"],
      },
    );
  }
}
