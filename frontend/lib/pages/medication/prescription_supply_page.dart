import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/medication_api.dart';

class PrescriptionSupplyPage extends StatefulWidget {
  final Map<String, dynamic> prescription;
  final Map<String, dynamic> medication;
  final String drugName;

  const PrescriptionSupplyPage({
    super.key,
    required this.prescription,
    required this.medication,
    required this.drugName,
  });

  @override
  State<PrescriptionSupplyPage> createState() => _PrescriptionSupplyPageState();
}

class _PrescriptionSupplyPageState extends State<PrescriptionSupplyPage> {
  static const bg = Color(0xFFFBF2EB);
  static const titleColor = Color(0xFFD88442);
  static const accent = Color(0xFF917869);
  static const muted = Color(0xFF676767);

  late Map<String, dynamic> _rx;
  Map<String, dynamic>? _updatedMed;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _rx = widget.prescription;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  int get _refillsLeft {
    final authorized = (_rx["refills_authorized"] as int?) ?? 0;
    final used = (_rx["refills_used"] as int?) ?? 0;
    return authorized - used;
  }

  /// Mirrors the _calculatedLastDay logic from the form page.
  /// Returns today + daysFromToday based on [quantity] (or quantity_total if
  /// omitted), dose, and schedule.
  DateTime? _recalculateEndDate({double? quantity}) {
    final total = quantity ?? double.tryParse(_rx["quantity_total"]?.toString() ?? "");
    final dose = double.tryParse(_rx["dose_amount"]?.toString() ?? "");
    if (total == null || total <= 0 || dose == null || dose <= 0) return null;

    final qtyUnit = (_rx["quantity_unit"] ?? "").toString().toLowerCase();
    final doseUnit = (_rx["dose_unit"] ?? "").toString().toLowerCase();
    if (qtyUnit.isEmpty || doseUnit.isEmpty || qtyUnit != doseUnit) return null;

    final schedules =
        (widget.medication["schedules"] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final asNeeded = widget.medication["as_needed"] == true;
    if (asNeeded || schedules.isEmpty) return null;

    final type = (schedules.first["schedule_type"] as String?) ?? "";
    double dosesPerDay;

    switch (type) {
      case "fixed_times":
        dosesPerDay = schedules
            .where((s) => s["schedule_type"] == "fixed_times")
            .length
            .toDouble();
        if (dosesPerDay <= 0) dosesPerDay = 1;
      case "interval":
        final hours = (schedules.first["interval_hours"] as int?) ?? 0;
        if (hours <= 0) return null;
        dosesPerDay = 24 / hours;
      case "weekly":
        final days =
            (schedules.first["days_of_week"] as List?)?.cast<String>() ?? [];
        final daysPerWeek = days.length;
        if (daysPerWeek == 0) return null;
        final timesPerDay = schedules
            .where((s) => s["schedule_type"] == "weekly")
            .length
            .toDouble();
        dosesPerDay = (daysPerWeek * (timesPerDay > 0 ? timesPerDay : 1)) / 7;
      default:
        return null;
    }

    if (dosesPerDay <= 0) return null;
    final totalDoses = total / dose;
    final daysFromToday = ((totalDoses - 1) / dosesPerDay).floor();
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day)
        .add(Duration(days: daysFromToday));
  }

  /// Marks the medication active again and stores the result so it propagates
  /// back to MedicationDetailPage when the user navigates away.
  Future<void> _reactivateMedication() async {
    try {
      final updated = await MedicationApi.updateMedication(
        id: widget.medication["id"] as int,
        body: {"status": "active"},
      );
      if (mounted) setState(() => _updatedMed = updated);
    } catch (e) {
      debugPrint("Failed to reactivate medication: $e");
    }
  }

  Future<void> _onUseRefillPressed() async {
    final totalVal = double.tryParse(_rx["quantity_total"]?.toString() ?? "");
    final remainVal = double.tryParse(_rx["quantity_remaining"]?.toString() ?? "");

    if (totalVal != null && totalVal > 0 && remainVal != null && remainVal / totalVal > 0.10) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Supply still available",
            style: TextStyle(color: muted, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            "You still have over 10% of your current supply remaining. Are you sure you want to use a refill now?",
            style: const TextStyle(color: muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Cancel", style: TextStyle(color: muted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Use refill"),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await _useRefill();
  }

  Future<void> _useRefill() async {
    final newRefillsUsed = ((_rx["refills_used"] as int?) ?? 0) + 1;
    final total = double.tryParse(_rx["quantity_total"]?.toString() ?? "") ?? 0;
    final currentRemaining =
        double.tryParse(_rx["quantity_remaining"]?.toString() ?? "") ?? 0;
    final newRemaining = currentRemaining + total;
    final newExpiration = _recalculateEndDate(quantity: newRemaining);

    final body = <String, dynamic>{
      "refills_used": newRefillsUsed,
      "quantity_remaining": newRemaining,
    };
    if (newExpiration != null) {
      body["expiration_date"] = _fmt(newExpiration);
    }

    setState(() => _isLoading = true);
    try {
      final updated = await MedicationApi.updatePrescription(
        prescriptionId: _rx["id"] as int,
        body: body,
      );
      if (!mounted) return;
      setState(() => _rx = updated);
      if (widget.medication["status"] == "completed") {
        await _reactivateMedication();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEdit() async {
    final medUnit = (widget.medication["dose_unit"]?.toString() ?? "");
    final unit = medUnit.isNotEmpty
        ? medUnit
        : (_rx["quantity_unit"] ?? "").toString();

    // Use a plain numeric string — NOT _formatQty (which returns "—" for null)
    // so double.tryParse always works on the initial value.
    final initialQtyText = () {
      final v = double.tryParse(_rx["quantity_remaining"]?.toString() ?? "");
      if (v == null) return "";
      return v.toStringAsFixed(4)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }();

    final qtyCtrl = TextEditingController(text: initialQtyText);
    final refillsCtrl = TextEditingController(
      text: ((_rx["refills_authorized"] as int?) ?? 0).toString(),
    );
    DateTime? lastDayOverride;

    DateTime? calcLastDay() {
      final qty = double.tryParse(qtyCtrl.text.trim());
      final dose = double.tryParse(_rx["dose_amount"]?.toString() ?? "");
      if (qty == null || qty <= 0 || dose == null || dose <= 0) return null;
      final qUnit = (_rx["quantity_unit"] ?? "").toString().toLowerCase();
      final dUnit = (_rx["dose_unit"] ?? "").toString().toLowerCase();
      if (qUnit.isEmpty || dUnit.isEmpty || qUnit != dUnit) return null;
      final schedules =
          (widget.medication["schedules"] as List?)
              ?.cast<Map<String, dynamic>>() ?? [];
      if (schedules.isEmpty || widget.medication["as_needed"] == true) return null;
      final type = (schedules.first["schedule_type"] as String?) ?? "";
      double dosesPerDay;
      switch (type) {
        case "fixed_times":
          dosesPerDay = schedules
              .where((s) => s["schedule_type"] == "fixed_times")
              .length.toDouble();
          if (dosesPerDay <= 0) dosesPerDay = 1;
        case "interval":
          final h = (schedules.first["interval_hours"] as int?) ?? 0;
          if (h <= 0) return null;
          dosesPerDay = 24 / h;
        case "weekly":
          final days = (schedules.first["days_of_week"] as List?)?.cast<String>() ?? [];
          if (days.isEmpty) return null;
          final times = schedules.where((s) => s["schedule_type"] == "weekly").length;
          dosesPerDay = (days.length * (times > 0 ? times : 1)) / 7;
        default:
          return null;
      }
      if (dosesPerDay <= 0) return null;
      final daysFrom = ((qty / dose - 1) / dosesPerDay).floor();
      final today = DateTime.now();
      return DateTime(today.year, today.month, today.day).add(Duration(days: daysFrom));
    }

    String fmtDate(DateTime d) =>
        "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    bool saving = false;
    String? qtyError;
    void Function(void Function())? _sheetSetter;
    final qtyFocus = FocusNode();
    qtyFocus.addListener(() {
      if (!qtyFocus.hasFocus) _sheetSetter?.call(() {});
    });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          _sheetSetter = setSheet;

          final calculated = calcLastDay();
          final isOverride = lastDayOverride != null;
          final displayed = isOverride ? lastDayOverride : calculated;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Edit prescription",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                      TextButton(
                        onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                        child: const Text("Cancel",
                            style: TextStyle(color: muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Quantity left + unit
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _sheetField(
                          label: "Quantity left",
                          child: TextFormField(
                            controller: qtyCtrl,
                            focusNode: qtyFocus,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                            decoration: _inputDec("e.g. 30").copyWith(
                              errorText: qtyError,
                            ),
                            onTap: () {
                              qtyCtrl.selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: qtyCtrl.text.length,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _sheetField(
                          label: "Unit",
                          child: TextFormField(
                            initialValue: unit,
                            readOnly: true,
                            decoration: _inputDec("").copyWith(
                              fillColor: const Color(0xFFF0EBE5),
                            ),
                            style: const TextStyle(color: Color(0xFF9E9E9E)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Expected end date
                  _sheetField(
                    label: "Expected end date",
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: lastDayOverride ?? calculated ?? DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2099),
                            );
                            if (picked != null) setSheet(() => lastDayOverride = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFDDD5CE)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isOverride ? Icons.edit_calendar_outlined : Icons.calculate_outlined,
                                  size: 18,
                                  color: muted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    displayed != null
                                        ? _formatDate(fmtDate(displayed))
                                        : (calculated == null ? "Fill in quantity & schedule" : "—"),
                                    style: TextStyle(
                                      color: displayed != null ? muted : Colors.grey,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (isOverride)
                                  GestureDetector(
                                    onTap: () => setSheet(() => lastDayOverride = null),
                                    child: const Tooltip(
                                      message: "Revert to calculated",
                                      child: Icon(Icons.refresh, size: 18, color: muted),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (displayed != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 2),
                            child: Text(
                              isOverride ? "Manually set — tap ↻ to recalculate" : "Auto-calculated from schedule",
                              style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Refills authorized
                  _sheetField(
                    label: "Refills authorized",
                    child: TextFormField(
                      controller: refillsCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDec("0"),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              // Validate quantity field before attempting save
                              final qty = double.tryParse(qtyCtrl.text.trim());
                              if (qty == null) {
                                setSheet(() => qtyError = "Enter a valid number");
                                return;
                              }
                              setSheet(() {
                                saving = true;
                                qtyError = null;
                              });

                              final refills = int.tryParse(refillsCtrl.text.trim()) ?? 0;
                              final effectiveDate = lastDayOverride ?? calcLastDay();
                              final rxId = _rx["id"] is int
                                  ? _rx["id"] as int
                                  : int.tryParse(_rx["id"]?.toString() ?? "");
                              if (rxId == null) {
                                setSheet(() => saving = false);
                                return;
                              }
                              final body = <String, dynamic>{
                                "quantity_remaining": qty,
                                "refills_authorized": refills,
                                if (effectiveDate != null)
                                  "expiration_date": fmtDate(effectiveDate),
                              };
                              final shouldReactivate =
                                  qty > 0 && widget.medication["status"] == "completed";
                              try {
                                final updated = await MedicationApi.updatePrescription(
                                  prescriptionId: rxId,
                                  body: body,
                                );
                                if (!mounted) return;
                                setState(() => _rx = updated);
                                Navigator.of(ctx).pop();
                                if (shouldReactivate) {
                                  await _reactivateMedication();
                                }
                              } catch (e) {
                                if (!mounted) return;
                                setSheet(() => saving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Save changes",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    _sheetSetter = null;
    qtyFocus.dispose();
  }

  String _fmt(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Use the medication's dose_unit as source of truth — quantity_unit on the
    // prescription may be stale if the dose unit was changed after creation.
    final unit = ((widget.medication["dose_unit"]?.toString() ?? "").isNotEmpty
            ? widget.medication["dose_unit"].toString()
            : (_rx["quantity_unit"] ?? "").toString());
    final quantityTotal = _rx["quantity_total"];
    final quantityRemaining = _rx["quantity_remaining"];
    final expirationStr = (_rx["expiration_date"] ?? "").toString();
    final startStr = (_rx["start_date"] ?? "").toString();
    final refillsAuthorized = (_rx["refills_authorized"] as int?) ?? 0;
    final refillsUsed = (_rx["refills_used"] as int?) ?? 0;
    // Show the medication's status (active/paused/stopped/completed), not the prescription status
    final status = (widget.medication["status"] ?? "active").toString();

    final totalText = _formatQty(quantityTotal, unit);
    final remainingText = _formatQty(quantityRemaining, unit);

    double? progress;
    final totalVal = double.tryParse(quantityTotal?.toString() ?? "");
    final remainVal = double.tryParse(quantityRemaining?.toString() ?? "");
    if (totalVal != null && totalVal > 0 && remainVal != null) {
      progress = (remainVal / totalVal).clamp(0.0, 1.0);
    }

    return PopScope<Map<String, dynamic>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop({"rx": _rx, "med": _updatedMed});
      },
      child: Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: BackButton(color: muted, onPressed: () => Navigator.of(context).pop({"rx": _rx, "med": _updatedMed})),
        title: Text(
          widget.drugName,
          style: const TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 18, color: accent),
            label: const Text("Edit", style: TextStyle(color: accent)),
            onPressed: _handleEdit,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Prescription supply",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: muted,
              ),
            ),
            const SizedBox(height: 4),
            _statusBadge(status),
            const SizedBox(height: 12),
            if (widget.medication["status"] == "paused") ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.pause_circle_outline, size: 16, color: Color(0xFFFF9800)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Medication is paused — supply tracking is on hold",
                        style: TextStyle(fontSize: 13, color: Color(0xFFFF9800)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Supply progress card
            _card([
              _row("Total prescribed", totalText),
              _row("Remaining", remainingText),
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFEEE8E3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress < 0.2 ? Colors.red.shade400 : accent,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${(progress * 100).round()}% remaining",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ]),

            const SizedBox(height: 14),

            // Dates card
            _card([
              _row("Start date",
                  startStr.isNotEmpty ? _formatDate(startStr) : "—"),
              _row(
                "Expected end",
                expirationStr.isNotEmpty ? _formatDate(expirationStr) : "—",
              ),
              if (expirationStr.isNotEmpty)
                _daysRemainingLabel(expirationStr),
            ]),

            const SizedBox(height: 14),

            // Refills card
            _card([
              _row("Refills authorized", refillsAuthorized.toString()),
              _row("Refills used", refillsUsed.toString()),
              _row(
                "Refills left",
                _refillsLeft.toString(),
                valueColor:
                    _refillsLeft == 0 ? Colors.red.shade400 : null,
              ),
            ]),

            const SizedBox(height: 20),

            // Use refill button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: const Text(
                  "Use a refill",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                onPressed: (_refillsLeft > 0 && !_isLoading) ? _onUseRefillPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFDDD5CE),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_refillsLeft == 0)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Center(
                  child: Text(
                    "No refills remaining",
                    style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _sheetField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  InputDecoration _inputDec(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBBB3AC)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDD5CE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDD5CE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: accent),
      ),
    );
  }

  Widget _card(List<Widget> children) {
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
        children: children,
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? muted,
                fontWeight:
                    valueColor != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _daysRemainingLabel(String raw) {
    final daysLeft = _daysUntil(raw);
    if (daysLeft == null) return const SizedBox.shrink();
    final label = daysLeft < 0
        ? "Expired ${-daysLeft} day${-daysLeft == 1 ? '' : 's'} ago"
        : daysLeft == 0
            ? "Expires today"
            : "$daysLeft day${daysLeft == 1 ? '' : 's'} remaining";
    final color = daysLeft < 0
        ? Colors.red.shade400
        : daysLeft <= 7
            ? Colors.orange.shade600
            : const Color(0xFF4CAF50);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
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
      "expired" => ("Expired", const Color(0xFFE53935)),
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

  // ── Formatters ─────────────────────────────────────────────────────────────

  String _formatQty(dynamic qty, String unit) {
    if (qty == null) return "—";
    final val = double.tryParse(qty.toString());
    if (val == null) return "—";
    final numStr = val.toStringAsFixed(4).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return unit.isNotEmpty ? "$numStr $unit" : numStr;
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  int? _daysUntil(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final expOnly = DateTime(dt.year, dt.month, dt.day);
      return expOnly.difference(todayOnly).inDays;
    } catch (_) {
      return null;
    }
  }
}
