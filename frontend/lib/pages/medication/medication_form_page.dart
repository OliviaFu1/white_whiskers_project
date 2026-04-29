import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/medication_api.dart';
import 'package:frontend/services/notification_service.dart';

class MedicationFormPage extends StatefulWidget {
  final int petId;
  final String petName;

  /// Non-null = edit mode
  final Map<String, dynamic>? medication;

  const MedicationFormPage({
    super.key,
    required this.petId,
    required this.petName,
    this.medication,
  });

  @override
  State<MedicationFormPage> createState() => _MedicationFormPageState();
}

class _MedicationFormPageState extends State<MedicationFormPage> {
  static const bg = Color(0xFFFBF2EB);
  static const titleColor = Color(0xFFD88442);
  static const accent = Color(0xFF917869);
  static const muted = Color(0xFF676767);

  final _formKey = GlobalKey<FormState>();

  // Required fields
  final _drugNameCtrl = TextEditingController();
  final _doseAmountCtrl = TextEditingController();
  final _doseUnitCtrl = TextEditingController();
  final _sigTextCtrl = TextEditingController();

  // Combined form+route picker — split into two fields on save
  String? _typeCategory; // "oral_solid" | "other_type"
  String? _formRoute;
  String? _lastOralRoute; // remembered selection when in oral_solid
  String? _lastOtherRoute; // remembered selection when in other_type
  final _otherTypeCtrl = TextEditingController();

  DateTime? _startDate;

  // Optional fields
  final _vetNameCtrl = TextEditingController();
  final _vetClinicCtrl = TextEditingController();
  bool? _withFood;
  // Schedule
  String _howOften = "once_daily";
  TimeOfDay? _onceDailyTime;
  final List<TimeOfDay> _multiDailyTimes = [];
  final List<TimeOfDay> _specificDaysTimes = [];
  final _intervalDaysCtrl = TextEditingController();
  final List<TimeOfDay> _intervalDaysTimes = [];
  final _maxDosesCtrl = TextEditingController();
  final Set<String> _daysOfWeek = {};

  // Prescription supply
  bool _trackPrescription = false;
  int? _existingPrescriptionId;
  final _qtyTotalCtrl = TextEditingController();
  final _qtyTotalFocusNode = FocusNode();
  final _qtyUnitCtrl = TextEditingController();
  // null = use auto-calculated; non-null = user manually overrode the date
  DateTime? _lastDayOverride;
  final _refillsAuthorizedCtrl = TextEditingController(text: "0");
  final _prescriptionNotesCtrl = TextEditingController();

  bool _isSaving = false;
  bool _isDeleting = false;
  String? _errorText;
  bool _triedSubmit = false;

  static const _defaultDoseUnit = {
    "tablet_oral": "tablets",
    "capsule_oral": "capsules",
    "liquid_oral": "ml",
    "drops": "drops",
    "injection": "ml",
    "inhaler": "puffs",
    "topical": "applications",
    // "other" intentionally omitted — no sensible default
  };

  /// key → (form, route, display label, icon)
  static const _formRouteOptions = [
    // Oral (support supply tracking)
    ("tablet_oral", "tablet", "oral", "Tablet", Icons.medication),
    ("capsule_oral", "capsule", "oral", "Capsule", Icons.medication_liquid),
    ("liquid_oral", "liquid", "oral", "Liquid (oral)", Icons.water_drop),
    // Other
    ("drops", "liquid", "ophthalmic", "Drops", Icons.water_drop),
    ("injection", "injection", "injectable", "Injection", Icons.vaccines),
    ("topical", "topical", "topical", "Topical", Icons.back_hand),
    ("inhaler", "other", "inhaled", "Inhaler", Icons.air),
    ("other", "other", "other", "Other", Icons.more_horiz),
  ];

  static const _oralSolidKeys = {"tablet_oral", "capsule_oral", "liquid_oral"};

  bool get _isOralSolid => _oralSolidKeys.contains(_formRoute);

  /// Reverse-map stored (form, route, form_description) → combined key
  static String? _formRouteKey(String? form, String? route) {
    if (form == null || route == null) return null;
    // Both ophthalmic and otic liquid routes map to the combined "drops" option.
    if (form == "liquid" && (route == "ophthalmic" || route == "otic")) {
      return "drops";
    }
    for (final o in _formRouteOptions) {
      if (o.$2 == form && o.$3 == route) return o.$1;
    }
    return null;
  }

  static const _weekdays = [
    ("mon", "Mon"),
    ("tue", "Tue"),
    ("wed", "Wed"),
    ("thu", "Thu"),
    ("fri", "Fri"),
    ("sat", "Sat"),
    ("sun", "Sun"),
  ];

  bool get _isEdit => widget.medication != null;

  /// Calculates the expected last day of medication from quantity, dose, and
  /// schedule. Returns null if data is incomplete or units don't match.
  DateTime? get _calculatedLastDay {
    final qty = double.tryParse(_qtyTotalCtrl.text.trim());
    final dose = double.tryParse(_doseAmountCtrl.text.trim());
    if (qty == null || qty <= 0 || dose == null || dose <= 0) return null;

    // In edit mode, calculate forward from today (when user updates quantity left).
    // In add mode, calculate forward from the start date.
    final baseDate = (_isEdit && _existingPrescriptionId != null)
        ? DateTime.now()
        : _startDate;
    if (baseDate == null) return null;

    final qtyUnit = _qtyUnitCtrl.text.trim().toLowerCase();
    final doseUnit = _doseUnitCtrl.text.trim().toLowerCase();
    if (qtyUnit.isEmpty || doseUnit.isEmpty || qtyUnit != doseUnit) return null;

    final totalDoses = qty / dose;

    double dosesPerDay;
    switch (_howOften) {
      case "once_daily":
        dosesPerDay = 1.0;
      case "multiple_daily":
        dosesPerDay = (_multiDailyTimes.isEmpty ? 1 : _multiDailyTimes.length)
            .toDouble();
      case "every_x_days":
        final days = int.tryParse(_intervalDaysCtrl.text.trim());
        if (days == null || days <= 0) return null;
        dosesPerDay = 1.0 / days;
      case "specific_days":
        final daysPerWeek = _daysOfWeek.length;
        if (daysPerWeek == 0) return null;
        final timesPerDay =
            (_specificDaysTimes.isEmpty ? 1 : _specificDaysTimes.length)
                .toDouble();
        dosesPerDay = (daysPerWeek * timesPerDay) / 7.0;
      default:
        return null; // as_needed or unknown
    }

    if (dosesPerDay <= 0) return null;
    final daysFromStart = ((totalDoses - 1) / dosesPerDay).floor();
    return baseDate.add(Duration(days: daysFromStart));
  }

  void _rebuildOnChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    // Rebuild whenever fields that affect _calculatedLastDay change.
    // Quantity rebuilds on blur only; dose/unit rebuild on every change.
    _qtyTotalFocusNode.addListener(() {
      if (!_qtyTotalFocusNode.hasFocus) _rebuildOnChange();
    });
    _doseAmountCtrl.addListener(_rebuildOnChange);
    _doseUnitCtrl.addListener(_rebuildOnChange);
    _qtyUnitCtrl.addListener(_rebuildOnChange);

    final med = widget.medication;
    if (med == null) return;

    _drugNameCtrl.text = (med["drug_name"] ?? "").toString();
    _doseAmountCtrl.text = _fmtNum(med["dose_amount"]);
    _doseUnitCtrl.text = (med["dose_unit"] ?? "").toString();
    _sigTextCtrl.text = (med["sig_text"] ?? "").toString();
    _vetNameCtrl.text = (med["prescribing_vet_name"] ?? "").toString();
    _vetClinicCtrl.text = (med["prescribing_vet_clinic"] ?? "").toString();
    final formDesc = (med["form_description"] ?? "").toString();
    _formRoute = _formRouteKey(
      med["form"]?.toString(),
      med["route"]?.toString(),
    );
    if (_formRoute != null) {
      _typeCategory = _oralSolidKeys.contains(_formRoute)
          ? "oral_solid"
          : "other_type";
      if (_oralSolidKeys.contains(_formRoute)) {
        _lastOralRoute = _formRoute;
      } else {
        _lastOtherRoute = _formRoute;
      }
    }
    if (_formRoute == "other") {
      _otherTypeCtrl.text = formDesc;
    }

    final startStr = med["start_date"]?.toString() ?? "";
    if (startStr.isNotEmpty) {
      try {
        _startDate = DateTime.parse(startStr);
      } catch (_) {}
    }

    final wf = med["with_food"];
    if (wf is bool) _withFood = wf;

    final prescriptions =
        (med["prescriptions"] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (prescriptions.isNotEmpty) {
      final p = prescriptions.first;
      _trackPrescription = true;
      _existingPrescriptionId = p["id"] as int?;
      _qtyTotalCtrl.text = _fmtNum(p["quantity_remaining"]);
      // quantity_unit must always match dose_unit; use dose_unit as source of
      // truth to avoid showing a stale prescription value.
      _qtyUnitCtrl.text = _doseUnitCtrl.text;
      _refillsAuthorizedCtrl.text = (p["refills_authorized"] ?? 0).toString();
      _prescriptionNotesCtrl.text = (p["notes"] ?? "").toString();
      // Don't pre-populate _lastDayOverride — let it auto-calculate from quantity.
    }

    final asNeeded = med["as_needed"] == true;
    final schedules =
        (med["schedules"] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (asNeeded) {
      _howOften = "as_needed";
      _maxDosesCtrl.text = (med["max_doses_per_day"] ?? "").toString();
    } else if (schedules.isNotEmpty) {
      final type =
          (schedules.first["schedule_type"] as String?) ?? "fixed_times";
      if (type == "interval") {
        _howOften = "every_x_days";
        final hours = schedules.first["interval_hours"] as int? ?? 0;
        if (hours > 0) _intervalDaysCtrl.text = (hours ~/ 24).toString();
        _intervalDaysTimes.addAll(_parseTimes(schedules));
      } else if (type == "weekly") {
        _howOften = "specific_days";
        final days =
            (schedules.first["days_of_week"] as List?)?.cast<String>() ?? [];
        _daysOfWeek.addAll(days);
        _specificDaysTimes.addAll(_parseTimes(schedules));
      } else {
        final fixed = schedules
            .where((s) => s["schedule_type"] == "fixed_times")
            .toList();
        final parsed = _parseTimes(fixed);
        if (fixed.length > 1) {
          _howOften = "multiple_daily";
          _multiDailyTimes.addAll(parsed);
        } else {
          _howOften = "once_daily";
          if (parsed.isNotEmpty) _onceDailyTime = parsed.first;
        }
      }
    }
  }

  List<TimeOfDay> _parseTimes(List<Map<String, dynamic>> schedules) {
    final result = <TimeOfDay>[];
    for (final s in schedules) {
      final t = s["time_of_day"]?.toString() ?? "";
      if (t.isNotEmpty) {
        final parts = t.split(":");
        if (parts.length >= 2) {
          result.add(
            TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 0,
              minute: int.tryParse(parts[1]) ?? 0,
            ),
          );
        }
      }
    }
    return result;
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

  void dispose() {
    _qtyTotalFocusNode.dispose();
    _doseAmountCtrl.removeListener(_rebuildOnChange);
    _doseUnitCtrl.removeListener(_rebuildOnChange);
    _qtyUnitCtrl.removeListener(_rebuildOnChange);
    _drugNameCtrl.dispose();
    _doseAmountCtrl.dispose();
    _doseUnitCtrl.dispose();
    _sigTextCtrl.dispose();
    _vetNameCtrl.dispose();
    _vetClinicCtrl.dispose();
    _intervalDaysCtrl.dispose();
    _maxDosesCtrl.dispose();
    _otherTypeCtrl.dispose();
    _qtyTotalCtrl.dispose();
    _qtyUnitCtrl.dispose();
    _refillsAuthorizedCtrl.dispose();
    _prescriptionNotesCtrl.dispose();
    super.dispose();
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
          _isEdit
              ? "Edit medication for ${widget.petName}"
              : "Add medication for ${widget.petName}",
          style: const TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: _isEdit
            ? [
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    "Delete",
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: (_isSaving || _isDeleting) ? null : _handleDelete,
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section("Medication"),
              _field(
                label: "Drug name *",
                child: TextFormField(
                  controller: _drugNameCtrl,
                  decoration: _inputDec("e.g. Amoxicillin"),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
              ),
              const SizedBox(height: 14),
              _formRoutePicker(),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _field(
                      label: "Dose amount *",
                      child: TextFormField(
                        controller: _doseAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        decoration: _inputDec("e.g. 1.5"),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Required";
                          if (double.tryParse(v.trim()) == null) {
                            return "Enter a number";
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _field(
                      label: "Dose unit *",
                      child: _formRoute == "tablet_oral"
                          ? DropdownButtonFormField<String>(
                              value:
                                  [
                                    "tablets",
                                    "chewables",
                                  ].contains(_doseUnitCtrl.text)
                                  ? _doseUnitCtrl.text
                                  : "tablets",
                              decoration: _inputDec(""),
                              items: const [
                                DropdownMenuItem(
                                  value: "tablets",
                                  child: Text("tablets"),
                                ),
                                DropdownMenuItem(
                                  value: "chewables",
                                  child: Text("chewables"),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _doseUnitCtrl.text = v;
                                    _qtyUnitCtrl.text = v;
                                  });
                                }
                              },
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? "Required" : null,
                            )
                          : TextFormField(
                              controller: _doseUnitCtrl,
                              readOnly: _formRoute != "other",
                              decoration: _formRoute == "other"
                                  ? _inputDec("e.g. drops, patch…")
                                  : _inputDec("tablet / ml / capsule").copyWith(
                                      fillColor: const Color(0xFFF0EBE5),
                                    ),
                              style: _formRoute != "other"
                                  ? const TextStyle(color: Color(0xFF9E9E9E))
                                  : null,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? "Required"
                                  : null,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _field(
                label: "Instructions (sig) *",
                child: TextFormField(
                  controller: _sigTextCtrl,
                  decoration: _inputDec(
                    "e.g. Give 1 tablet by mouth twice daily",
                  ),
                  maxLines: 2,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
              ),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "What's this medication for?",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message:
                            "Not sure? Ask your vet what this medication is treating.",
                        triggerMode: TooltipTriggerMode.tap,
                        child: const Icon(
                          Icons.help_outline,
                          size: 15,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _prescriptionNotesCtrl,
                    decoration: _inputDec(
                      "e.g. Ear infection, pain relief, allergies…",
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _field(
                label: "Start date *",
                child: GestureDetector(
                  onTap: _pickStartDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_triedSubmit && _startDate == null)
                            ? Colors.red
                            : const Color(0xFFDDD5CE),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: muted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _startDate != null
                              ? _formatDate(_startDate!)
                              : "Select date",
                          style: TextStyle(
                            color: _startDate != null ? muted : Colors.grey,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_triedSubmit && _startDate == null)
                const Padding(
                  padding: EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    "Required",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 22),
              _section("How often?"),
              _howOftenSelector(),
              const SizedBox(height: 14),
              _howOftenDetails(),

              const SizedBox(height: 22),
              _section("Optional details"),
              _field(
                label: "Prescribing vet",
                child: TextFormField(
                  controller: _vetNameCtrl,
                  decoration: _inputDec("Dr. Smith"),
                ),
              ),
              const SizedBox(height: 14),
              _field(
                label: "Clinic",
                child: TextFormField(
                  controller: _vetClinicCtrl,
                  decoration: _inputDec("e.g. City Animal Hospital"),
                ),
              ),
              const SizedBox(height: 14),
              _withFoodToggle(),

              if (_isOralSolid && _howOften != "as_needed") ...[
                const SizedBox(height: 22),
                _section("Prescription supply"),
                _prescriptionToggle(),
                if (_trackPrescription) ...[
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _field(
                          label: _isEdit ? "Quantity left *" : "Total amount *",
                          child: TextFormField(
                            controller: _qtyTotalCtrl,
                            focusNode: _qtyTotalFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.]'),
                              ),
                            ],
                            decoration: _inputDec("e.g. 30"),
                            validator: (v) {
                              if (!_trackPrescription) return null;
                              if (v == null || v.trim().isEmpty)
                                return "Required";
                              final n = double.tryParse(v.trim());
                              if (n == null || n < 0) return "Must be ≥ 0";
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _field(
                          label: "Unit *",
                          child: TextFormField(
                            controller: _qtyUnitCtrl,
                            readOnly: true,
                            decoration: _inputDec(
                              "tablet / ml / capsule",
                            ).copyWith(fillColor: const Color(0xFFF0EBE5)),
                            style: const TextStyle(color: Color(0xFF9E9E9E)),
                            validator: (v) {
                              if (!_trackPrescription) return null;
                              return (v == null || v.trim().isEmpty)
                                  ? "Required"
                                  : null;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _lastDayField(),
                  const SizedBox(height: 14),
                  _field(
                    label: "Refills authorized",
                    child: TextFormField(
                      controller: _refillsAuthorizedCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDec("0"),
                    ),
                  ),
                ],
              ], // end _isOralSolid

              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],

              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? "Save changes" : "Save medication",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF676767),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "Discard changes",
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }

  Widget _field({required String label, required Widget child}) {
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
        borderSide: const BorderSide(color: Color(0xFF917869)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  Widget _howOftenSelector() {
    const options = [
      ("once_daily", "Once per day"),
      ("multiple_daily", "Multiple times per day"),
      ("every_x_days", "Every X days"),
      ("specific_days", "Specific days of the week"),
      ("as_needed", "As needed (PRN)"),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final selected = _howOften == o.$1;
        return ChoiceChip(
          label: Text(o.$2),
          selected: selected,
          selectedColor: accent.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: selected ? accent : muted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selected ? accent : const Color(0xFFDDD5CE),
            ),
          ),
          backgroundColor: Colors.white,
          onSelected: (_) => setState(() {
            _howOften = o.$1;
            if (o.$1 == "as_needed") _trackPrescription = false;
          }),
        );
      }).toList(),
    );
  }

  Widget _howOftenDetails() {
    switch (_howOften) {
      case "once_daily":
        return _timeTile(
          time: _onceDailyTime,
          hasError: _triedSubmit && _onceDailyTime == null,
          onTap: () => _pickTime(
            initial: _onceDailyTime,
            onPicked: (t) => setState(() => _onceDailyTime = t),
          ),
        );

      case "multiple_daily":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._multiDailyTimes.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _timeTile(
                        time: e.value,
                        hasError: false,
                        onTap: () => _pickTime(
                          initial: e.value,
                          onPicked: (t) =>
                              setState(() => _multiDailyTimes[e.key] = t),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _multiDailyTimes.removeAt(e.key)),
                      child: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_triedSubmit && _multiDailyTimes.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  "Add at least one time",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add time"),
              style: TextButton.styleFrom(foregroundColor: accent),
              onPressed: () => _pickTime(
                onPicked: (t) => setState(() => _multiDailyTimes.add(t)),
              ),
            ),
          ],
        );

      case "every_x_days":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(
              label: "Repeat every (days) *",
              child: TextFormField(
                controller: _intervalDaysCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDec("e.g. 3"),
                validator: (v) {
                  if (_howOften != "every_x_days") return null;
                  if (v == null || v.trim().isEmpty) return "Required";
                  if (int.tryParse(v.trim()) == null)
                    return "Enter a whole number";
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            ..._intervalDaysTimes.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _timeTile(
                        time: e.value,
                        hasError: false,
                        label: "Time (optional)",
                        onTap: () => _pickTime(
                          initial: e.value,
                          onPicked: (t) =>
                              setState(() => _intervalDaysTimes[e.key] = t),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _intervalDaysTimes.removeAt(e.key)),
                      child: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add time (optional)"),
              style: TextButton.styleFrom(foregroundColor: accent),
              onPressed: () => _pickTime(
                onPicked: (t) => setState(() => _intervalDaysTimes.add(t)),
              ),
            ),
          ],
        );

      case "specific_days":
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Days *",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _weekdays.map((d) {
                final selected = _daysOfWeek.contains(d.$1);
                return FilterChip(
                  label: Text(d.$2),
                  selected: selected,
                  selectedColor: accent.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: selected ? accent : muted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected ? accent : const Color(0xFFDDD5CE),
                    ),
                  ),
                  backgroundColor: Colors.white,
                  onSelected: (v) => setState(() {
                    if (v)
                      _daysOfWeek.add(d.$1);
                    else
                      _daysOfWeek.remove(d.$1);
                  }),
                );
              }).toList(),
            ),
            if (_triedSubmit && _daysOfWeek.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  "Select at least one day",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 14),
            ..._specificDaysTimes.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _timeTile(
                        time: e.value,
                        hasError: false,
                        label: "Time (optional)",
                        onTap: () => _pickTime(
                          initial: e.value,
                          onPicked: (t) =>
                              setState(() => _specificDaysTimes[e.key] = t),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _specificDaysTimes.removeAt(e.key)),
                      child: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add time (optional)"),
              style: TextButton.styleFrom(foregroundColor: accent),
              onPressed: () => _pickTime(
                onPicked: (t) => setState(() => _specificDaysTimes.add(t)),
              ),
            ),
          ],
        );

      case "as_needed":
        return _field(
          label: "Max doses per day (optional)",
          child: TextFormField(
            controller: _maxDosesCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDec("e.g. 4"),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _timeTile({
    required TimeOfDay? time,
    required bool hasError,
    required VoidCallback onTap,
    String label = "Time *",
  }) {
    return _field(
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasError ? Colors.red : const Color(0xFFDDD5CE),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_outlined, size: 18, color: muted),
              const SizedBox(width: 8),
              Text(
                time != null ? _formatTime(time) : "Select time",
                style: TextStyle(
                  color: time != null ? muted : Colors.grey,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectFormRoute(String key) {
    setState(() {
      _formRoute = key;
      _typeCategory = _oralSolidKeys.contains(key)
          ? "oral_solid"
          : "other_type";
      if (_oralSolidKeys.contains(key)) {
        _lastOralRoute = key;
      } else {
        _lastOtherRoute = key;
      }
      if (!_oralSolidKeys.contains(key)) _trackPrescription = false;
      final newDefault = _defaultDoseUnit[key];
      if (newDefault != null) {
        _doseUnitCtrl.text = newDefault;
        _qtyUnitCtrl.text = newDefault;
      } else if (key == "other") {
        _doseUnitCtrl.text = "";
        _qtyUnitCtrl.text = "";
      }
    });
  }

  Widget _formRoutePicker() {
    const oralOptions = [
      ("tablet_oral", "Tablet", Icons.medication),
      ("capsule_oral", "Capsule", Icons.medication_liquid),
      ("liquid_oral", "Liquid (oral)", Icons.water_drop),
    ];
    const otherOptions = [
      ("drops", "Drops", Icons.water_drop),
      ("injection", "Injection", Icons.vaccines),
      ("topical", "Topical", Icons.back_hand),
      ("inhaler", "Inhaler", Icons.air),
      ("other", "Other", Icons.more_horiz),
    ];

    final isOralSelected = _typeCategory == "oral_solid";
    final isOtherSelected = _typeCategory == "other_type";

    Widget typeChip(String key, String label, IconData icon) {
      final selected = _formRoute == key;
      return GestureDetector(
        onTap: () => _selectFormRoute(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? accent : const Color(0xFFDDD5CE),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? accent : muted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? accent : muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget categoryButton(String label, bool active, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: active ? accent : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? accent : const Color(0xFFDDD5CE),
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : muted,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Type *",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
            if (_triedSubmit && _formRoute == null) ...[
              const SizedBox(width: 8),
              const Text(
                "Required",
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        // Category row
        Row(
          children: [
            categoryButton("Oral", isOralSelected, () {
              if (_lastOralRoute != null) {
                _selectFormRoute(_lastOralRoute!);
              } else {
                setState(() {
                  _typeCategory = "oral_solid";
                  _formRoute = null;
                });
              }
            }),
            const SizedBox(width: 10),
            categoryButton("Other", isOtherSelected, () {
              if (_lastOtherRoute != null) {
                _selectFormRoute(_lastOtherRoute!);
              } else {
                setState(() {
                  _typeCategory = "other_type";
                  _formRoute = null;
                  _trackPrescription = false;
                });
              }
            }),
          ],
        ),
        // Sub-type chips
        if (isOralSelected) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: oralOptions
                .map((o) => typeChip(o.$1, o.$2, o.$3))
                .toList(),
          ),
        ],
        if (isOtherSelected) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: otherOptions
                .map((o) => typeChip(o.$1, o.$2, o.$3))
                .toList(),
          ),
          if (_formRoute == "other") ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: _otherTypeCtrl,
              decoration: _inputDec("Describe the type (e.g. powder, patch…)"),
              validator: (v) =>
                  (_formRoute == "other" && (v == null || v.trim().isEmpty))
                  ? "Please describe the type"
                  : null,
            ),
          ],
        ],
      ],
    );
  }

  Widget _prescriptionToggle() {
    return Row(
      children: [
        Switch(
          value: _trackPrescription,
          onChanged: (v) => setState(() => _trackPrescription = v),
          activeColor: accent,
        ),
        const SizedBox(width: 8),
        const Text(
          "Track prescription supply",
          style: TextStyle(fontSize: 15, color: muted),
        ),
      ],
    );
  }

  Widget _lastDayField() {
    final calculated = _calculatedLastDay;
    final isOverride = _lastDayOverride != null;
    final displayed = isOverride ? _lastDayOverride : calculated;

    return _field(
      label: "Expected last day",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _pickLastDayOverride,
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
                    isOverride
                        ? Icons.edit_calendar_outlined
                        : Icons.calculate_outlined,
                    size: 18,
                    color: muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayed != null
                          ? _formatDate(displayed)
                          : (calculated == null
                                ? "Fill in quantity, dose & schedule"
                                : "—"),
                      style: TextStyle(
                        color: displayed != null ? muted : Colors.grey,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (isOverride)
                    GestureDetector(
                      onTap: () => setState(() => _lastDayOverride = null),
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
                isOverride
                    ? "Manually set — tap ↻ to recalculate"
                    : "Auto-calculated from schedule",
                style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickLastDayOverride() async {
    final effective = _lastDayOverride ?? _calculatedLastDay;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          effective ??
          (_startDate ?? DateTime.now()).add(const Duration(days: 30)),
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime(2099),
    );
    if (picked != null) setState(() => _lastDayOverride = picked);
  }

  Widget _withFoodToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Give with food?",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            _withFoodChip(null, "Not specified"),
            _withFoodChip(true, "Yes"),
            _withFoodChip(false, "No"),
          ],
        ),
      ],
    );
  }

  Widget _withFoodChip(bool? value, String label) {
    final selected = _withFood == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: accent.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? accent : muted,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? accent : const Color(0xFFDDD5CE)),
      ),
      backgroundColor: Colors.white,
      onSelected: (_) => setState(() => _withFood = value),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2099),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour;
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final period = h < 12 ? 'AM' : 'PM';
    final mins = t.minute.toString().padLeft(2, '0');
    return '$hour12:$mins $period';
  }

  Future<void> _pickTime({
    required ValueChanged<TimeOfDay> onPicked,
    TimeOfDay? initial,
  }) async {
    int initHour = 8;
    int initMinute = 0;
    String initPeriod = 'AM';
    if (initial != null) {
      final h = initial.hour;
      initMinute = initial.minute;
      if (h == 0) {
        initHour = 12;
        initPeriod = 'AM';
      } else if (h < 12) {
        initHour = h;
        initPeriod = 'AM';
      } else if (h == 12) {
        initHour = 12;
        initPeriod = 'PM';
      } else {
        initHour = h - 12;
        initPeriod = 'PM';
      }
    }

    final hourCtrl = TextEditingController(
      text: initHour.toString().padLeft(2, '0'),
    );
    final minuteCtrl = TextEditingController(
      text: initMinute.toString().padLeft(2, '0'),
    );
    final hourScrollCtrl = FixedExtentScrollController(
      initialItem: initHour - 1,
    );
    final minuteScrollCtrl = FixedExtentScrollController(
      initialItem: initMinute,
    );
    final minuteFocus = FocusNode();

    int selectedHour = initHour;
    int selectedMinute = initMinute;
    String selectedPeriod = initPeriod;
    String? errorText;
    // prevents feedback loops when one side programmatically updates the other
    var syncing = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            InputDecoration timeInputDec() => InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
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

            return SizedBox(
              height: 400,
              child: Column(
                  children: [
                    // ── header ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: muted),
                            ),
                          ),
                          const Text(
                            'Select time',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                              fontSize: 16,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              final hVal = int.tryParse(hourCtrl.text.trim());
                              final mVal = int.tryParse(minuteCtrl.text.trim());
                              if (hVal == null || hVal < 1 || hVal > 12) {
                                setModalState(
                                  () => errorText = 'Hour must be 1–12',
                                );
                                return;
                              }
                              if (mVal == null || mVal < 0 || mVal > 59) {
                                setModalState(
                                  () => errorText = 'Minute must be 0–59',
                                );
                                return;
                              }
                              int h = hVal;
                              if (selectedPeriod == 'AM' && h == 12)
                                h = 0;
                              else if (selectedPeriod == 'PM' && h != 12)
                                h += 12;
                              FocusManager.instance.primaryFocus?.unfocus();
                              onPicked(TimeOfDay(hour: h, minute: mVal));
                              Navigator.of(ctx).pop();
                            },
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // ── text inputs + AM/PM button ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 20, 32, 12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: hourCtrl,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 2,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                  decoration: timeInputDec().copyWith(
                                    hintText: '__',
                                    hintStyle: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFCCC5BE),
                                    ),
                                    counterText: '',
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (v) {
                                    setModalState(() => errorText = null);
                                    final hVal = int.tryParse(v);
                                    if (hVal != null &&
                                        hVal >= 1 &&
                                        hVal <= 12) {
                                      selectedHour = hVal;
                                      syncing = true;
                                      hourScrollCtrl.jumpToItem(hVal - 1);
                                      syncing = false;
                                    }
                                    if (v.length == 2) {
                                      minuteFocus.requestFocus();
                                    }
                                  },
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  ':',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: minuteCtrl,
                                  focusNode: minuteFocus,
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 2,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                  decoration: timeInputDec().copyWith(
                                    hintText: '__',
                                    hintStyle: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFCCC5BE),
                                    ),
                                    counterText: '',
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (v) {
                                    setModalState(() => errorText = null);
                                    final mVal = int.tryParse(v);
                                    if (mVal != null &&
                                        mVal >= 0 &&
                                        mVal <= 59) {
                                      selectedMinute = mVal;
                                      syncing = true;
                                      minuteScrollCtrl.jumpToItem(mVal);
                                      syncing = false;
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () => setModalState(() {
                                  selectedPeriod = selectedPeriod == 'AM'
                                      ? 'PM'
                                      : 'AM';
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    selectedPeriod,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (errorText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                errorText!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // ── scroll wheels ──
                    Expanded(
                      child: Row(
                        children: [
                          // hour wheel
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: hourScrollCtrl,
                              itemExtent: 54,
                              diameterRatio: 1.4,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (i) {
                                if (syncing) return;
                                final h = ((i % 12) + 12) % 12 + 1;
                                setModalState(() {
                                  selectedHour = h;
                                  hourCtrl.text = h.toString().padLeft(2, '0');
                                });
                              },
                              childDelegate: ListWheelChildLoopingListDelegate(
                                children: List.generate(
                                  12,
                                  (i) => Center(
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w600,
                                        color: selectedHour == i + 1
                                            ? accent
                                            : muted.withOpacity(0.35),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // minute wheel
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: minuteScrollCtrl,
                              itemExtent: 54,
                              diameterRatio: 1.4,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (i) {
                                if (syncing) return;
                                final m = ((i % 60) + 60) % 60;
                                setModalState(() {
                                  selectedMinute = m;
                                  minuteCtrl.text = m.toString().padLeft(
                                    2,
                                    '0',
                                  );
                                });
                              },
                              childDelegate: ListWheelChildLoopingListDelegate(
                                children: List.generate(
                                  60,
                                  (i) => Center(
                                    child: Text(
                                      i.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w600,
                                        color: selectedMinute == i
                                            ? accent
                                            : muted.withOpacity(0.35),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  bool _validateForm() {
    setState(() => _triedSubmit = true);
    if (!_formKey.currentState!.validate()) return false;
    if (_formRoute == null) return false;
    if (_startDate == null) return false;
    if (_howOften == "once_daily" && _onceDailyTime == null) return false;
    if (_howOften == "multiple_daily" && _multiDailyTimes.isEmpty) return false;
    if (_howOften == "every_x_days" && _intervalDaysCtrl.text.trim().isEmpty)
      return false;
    if (_howOften == "specific_days" && _daysOfWeek.isEmpty) return false;
    return true;
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete medication?"),
        content: const Text(
          "This action cannot be undone. This medication will be permanently deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final medId = widget.medication!["id"] as int;
      await MedicationApi.deleteMedication(medId);
      await NotificationService.cancel(medId);
      if (!mounted) return;
      Navigator.of(context).pop({"__deleted": true});
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _handleSave() async {
    if (!_validateForm()) return;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      String _fmt(TimeOfDay t) {
        final h = t.hour.toString().padLeft(2, '0');
        final m = t.minute.toString().padLeft(2, '0');
        return "$h:$m:00";
      }

      final schedules = <Map<String, dynamic>>[];
      final bool asNeeded;
      switch (_howOften) {
        case "once_daily":
          asNeeded = false;
          if (_onceDailyTime != null) {
            schedules.add({
              "schedule_type": "fixed_times",
              "time_of_day": _fmt(_onceDailyTime!),
            });
          }
        case "multiple_daily":
          asNeeded = false;
          for (final t in _multiDailyTimes) {
            schedules.add({
              "schedule_type": "fixed_times",
              "time_of_day": _fmt(t),
            });
          }
        case "every_x_days":
          asNeeded = false;
          final intervalHours = int.parse(_intervalDaysCtrl.text.trim()) * 24;
          if (_intervalDaysTimes.isEmpty) {
            schedules.add({
              "schedule_type": "interval",
              "interval_hours": intervalHours,
            });
          } else {
            for (final t in _intervalDaysTimes) {
              schedules.add({
                "schedule_type": "interval",
                "interval_hours": intervalHours,
                "time_of_day": _fmt(t),
              });
            }
          }
        case "specific_days":
          asNeeded = false;
          const _dayOrder = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"];
          final weekdays = _daysOfWeek.toList()
            ..sort((a, b) => _dayOrder.indexOf(a).compareTo(_dayOrder.indexOf(b)));
          if (_specificDaysTimes.isEmpty) {
            schedules.add({
              "schedule_type": "weekly",
              "days_of_week": weekdays,
            });
          } else {
            for (final t in _specificDaysTimes) {
              schedules.add({
                "schedule_type": "weekly",
                "days_of_week": weekdays,
                "time_of_day": _fmt(t),
              });
            }
          }
        case "as_needed":
          asNeeded = true;
        default:
          asNeeded = false;
      }

      final rxOption = _formRouteOptions.firstWhere((o) => o.$1 == _formRoute);
      final body = <String, dynamic>{
        "pet_id": widget.petId,
        "drug_name": _drugNameCtrl.text.trim(),
        "form": rxOption.$2,
        "route": rxOption.$3,
        if (_formRoute == "tablet_oral" &&
            _doseUnitCtrl.text.trim() == "chewables")
          "form_description": "chewable"
        else if (_formRoute == "other" && _otherTypeCtrl.text.trim().isNotEmpty)
          "form_description": _otherTypeCtrl.text.trim(),
        "dose_amount": double.parse(_doseAmountCtrl.text.trim()),
        "dose_unit": _doseUnitCtrl.text.trim(),
        "sig_text": _sigTextCtrl.text.trim(),
        "start_date": _formatDate(_startDate!),
        "status": widget.medication?["status"]?.toString() ?? "active",
        "as_needed": asNeeded,
        "schedules": schedules,
      };
      final maxDoses = int.tryParse(_maxDosesCtrl.text.trim());
      if (maxDoses != null) body["max_doses_per_day"] = maxDoses;
      if (_vetNameCtrl.text.trim().isNotEmpty) {
        body["prescribing_vet_name"] = _vetNameCtrl.text.trim();
      }
      if (_vetClinicCtrl.text.trim().isNotEmpty) {
        body["prescribing_vet_clinic"] = _vetClinicCtrl.text.trim();
      }
      if (_withFood != null) {
        body["with_food"] = _withFood;
      }

      final Map<String, dynamic> result;
      if (_isEdit) {
        result = await MedicationApi.updateMedication(
          id: widget.medication!["id"] as int,
          body: body,
        );
      } else {
        result = await MedicationApi.createMedication(body: body);
      }
      if (!mounted) return;
      await NotificationService.syncFromMedication(result, widget.petName);
      if (!mounted) return;

      // Save prescription if toggled on
      if (_trackPrescription) {
        final medId = result["id"] as int;
        final qty = double.parse(_qtyTotalCtrl.text.trim());
        final rxBody = <String, dynamic>{
          // Creating a new prescription: qty is the total supply.
          // Updating an existing prescription: qty is the remaining amount.
          if (_existingPrescriptionId == null) "quantity_total": qty,
          if (_existingPrescriptionId != null) "quantity_remaining": qty,
          "quantity_unit": _qtyUnitCtrl.text.trim(),
          "dose_amount": double.parse(_doseAmountCtrl.text.trim()),
          "dose_unit": _doseUnitCtrl.text.trim(),
          "start_date": _formatDate(_startDate!),
          "refills_authorized":
              int.tryParse(_refillsAuthorizedCtrl.text.trim()) ?? 0,
          "notes": _prescriptionNotesCtrl.text.trim(),
        };
        final effectiveLastDay = _lastDayOverride ?? _calculatedLastDay;
        if (effectiveLastDay != null) {
          rxBody["expiration_date"] = _formatDate(effectiveLastDay);
        }
        final Map<String, dynamic> rxResult;
        if (_existingPrescriptionId != null) {
          rxResult = await MedicationApi.updatePrescription(
            prescriptionId: _existingPrescriptionId!,
            body: rxBody,
          );
        } else {
          rxResult = await MedicationApi.createPrescription(
            medicationId: medId,
            body: rxBody,
          );
        }
        if (!mounted) return;
        // Inject prescription back into result so initState can reload it
        // on the next edit (the PATCH/POST response omits nested prescriptions)
        result["prescriptions"] = [rxResult];
      } else {
        result["prescriptions"] = [];
      }

      Navigator.of(context).pop(result);
    } catch (e) {
      setState(() => _errorText = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
