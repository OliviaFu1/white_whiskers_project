import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/medication_api.dart';
import 'medication_detail_page.dart';
import 'medication_form_page.dart';

class PetMedicationsPage extends StatefulWidget {
  final int petId;
  final String petName;

  const PetMedicationsPage({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<PetMedicationsPage> createState() => _PetMedicationsPageState();
}

class _PetMedicationsPageState extends State<PetMedicationsPage> {
  static const bg = Color(0xFFFBF2EB);
  static const titleColor = Color(0xFFD88442);
  static const accent = Color(0xFF917869);
  static const muted = Color(0xFF676767);

  List<Map<String, dynamic>> _medications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Decrement prescription quantities for any doses that have elapsed
      try {
        await MedicationApi.processDueDoses(petId: widget.petId);
      } catch (e) {
        debugPrint("processDueDoses error: $e");
      }

      final meds = await MedicationApi.listMedications(petId: widget.petId);
      if (!mounted) return;
      setState(() => _medications = meds);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: const BackButton(color: muted),
        title: Text(
          "${widget.petName}'s Medications",
          style: const TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleAdd,
        backgroundColor: accent,
        child: const Icon(Icons.add, color: Colors.white),
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
          : _body(),
    );
  }

  Widget _body() {
    if (_medications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.medication_outlined, size: 56, color: muted),
              SizedBox(height: 16),
              Text(
                "No medications yet",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: muted,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Tap + to add a medication.",
                style: TextStyle(fontSize: 14, color: muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final active = _medications
        .where((m) => ["active", "paused"].contains(m["status"] ?? ""))
        .toList();
    final others = _medications
        .where((m) => !["active", "paused"].contains(m["status"] ?? ""))
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (active.isNotEmpty) ...[
            _sectionHeader("Active"),
            ...active.map(_medCard),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionHeader("Inactive"),
            ...others.map(_medCard),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }

  /// Lightweight refresh used after returning from a detail/edit page.
  /// Does not run auto-complete so a manually-reactivated medication
  /// is not immediately re-completed because its end_date is in the past.
  Future<void> _reload() async {
    try {
      final meds = await MedicationApi.listMedications(petId: widget.petId);
      if (!mounted) return;
      setState(() => _medications = meds);
    } catch (_) {}
  }

  Future<void> _openDetail(Map<String, dynamic> med) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationDetailPage(
          medication: med,
          petId: widget.petId,
          petName: widget.petName,
        ),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  Widget _medCard(Map<String, dynamic> med) {
    final drugName = (med["drug_name"] ?? "").toString();
    final doseAmount = _fmtNum(med["dose_amount"]);
    final doseUnit = (med["dose_unit"] ?? "").toString();
    final sigText = (med["sig_text"] ?? "").toString();
    final status = (med["status"] ?? "active").toString();
    final asNeeded = med["as_needed"] == true;
    final schedules =
        (med["schedules"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final schedSummary = asNeeded ? "As needed" : _scheduleSummary(schedules);

    final isActive = status == "active";

    return GestureDetector(
      onTap: () => _openDetail(med),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                blurRadius: 8,
                offset: Offset(0, 4),
                color: Color(0x18000000),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(status),
                  ],
                ),
                if (doseAmount.isNotEmpty || doseUnit.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    "$doseAmount ${doseAmount == "1" ? _singularUnit(doseUnit) : doseUnit}".trim(),
                    style: const TextStyle(fontSize: 14, color: muted),
                  ),
                ],
                if (sigText.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    sigText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (schedSummary != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.alarm_outlined, size: 13, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        schedSummary,
                        style: const TextStyle(fontSize: 12, color: accent),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

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

  String? _scheduleSummary(List<Map<String, dynamic>> schedules) {
    if (schedules.isEmpty) return null;
    final s = schedules.first;
    final type = s["schedule_type"] as String? ?? "";
    switch (type) {
      case "fixed_times":
        final t = s["time_of_day"]?.toString() ?? "";
        if (t.isEmpty) return "Daily";
        final parts = t.split(":");
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = parts[1].padLeft(2, '0');
          final ap = h >= 12 ? "PM" : "AM";
          final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
          return "Daily at $h12:$m $ap";
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
        return days.isEmpty ? "Weekly" : days.join(", ");
      default:
        return null;
    }
  }

  Future<void> _handleAdd() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) =>
            MedicationFormPage(petId: widget.petId, petName: widget.petName),
      ),
    );
    if (!mounted || result == null) return;
    await _load();
  }
}
