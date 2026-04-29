import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/pets_api.dart';

class PetFormPage extends StatefulWidget {
  /// null = create mode, non-null = edit mode
  final Map<String, dynamic>? pet;

  const PetFormPage({super.key, this.pet});

  @override
  State<PetFormPage> createState() => _PetFormPageState();
}

class _PetFormPageState extends State<PetFormPage> {
  static const bg = Color(0xFFFBF2EB);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);
  static const _chipShadow = [
    BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Color(0x11000000)),
  ];

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _breedCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _approxYearsCtrl;
  late final TextEditingController _approxMonthsCtrl;

  String? _species;
  String? _sex;
  bool? _spayedNeutered;
  bool _spayedAnswered = false;

  DateTime? _birthdate;
  bool _useBirthdateApprox = false;
  String? _birthdateError;

  String _photoUrl = "";
  XFile? _pendingPhoto;
  bool _uploadingPhoto = false;

  bool _isSaving = false;
  bool _isDeleting = false;
  bool _triedSubmit = false;
  String? _errorText;

  bool get _isEdit => widget.pet != null;
  bool get _busy => _isSaving || _isDeleting;

  @override
  void initState() {
    super.initState();
    final p = widget.pet;
    _nameCtrl = TextEditingController(text: p?["name"]?.toString() ?? "");
    _breedCtrl = TextEditingController(
      text: p?["breed_text"]?.toString() ?? "",
    );
    _weightCtrl = TextEditingController(
      text: p?["weight_kg"]?.toString() ?? "",
    );
    _approxYearsCtrl = TextEditingController();
    _approxMonthsCtrl = TextEditingController();
    _photoUrl = p?["photo_url"]?.toString() ?? "";
    _species = p?["species"]?.toString();
    _sex = p?["sex"]?.toString();

    final sn = p?["spayed_neutered"];
    if (sn is bool) {
      _spayedNeutered = sn;
      _spayedAnswered = true;
    } else if (sn == "true") {
      _spayedNeutered = true;
      _spayedAnswered = true;
    } else if (sn == "false") {
      _spayedNeutered = false;
      _spayedAnswered = true;
    } else if (_isEdit) {
      _spayedAnswered =
          true; // existing pet with null spayed_neutered = unknown
    }

    final bdRaw = p?["birthdate"];
    if (bdRaw != null) {
      try {
        _birthdate = DateTime.parse(bdRaw.toString());
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    _weightCtrl.dispose();
    _approxYearsCtrl.dispose();
    _approxMonthsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    if (_isEdit) {
      setState(() => _uploadingPhoto = true);
      try {
        final updated = await PetsApi.uploadPetPhoto(
          widget.pet!["id"] as int,
          image.path,
          mimeType: image.mimeType ?? 'image/jpeg',
        );
        if (!mounted) return;
        setState(() => _photoUrl = updated["photo_url"]?.toString() ?? "");
      } catch (e) {
        if (!mounted) return;
        setState(() => _errorText = e.toString());
      } finally {
        if (mounted) setState(() => _uploadingPhoto = false);
      }
    } else {
      setState(() => _pendingPhoto = image);
    }
  }

  /// Returns `(birthdateStr, isValid)`.
  (String?, bool) _computeBirthdate() {
    if (_useBirthdateApprox) {
      final years = int.tryParse(_approxYearsCtrl.text.trim()) ?? 0;
      final months = int.tryParse(_approxMonthsCtrl.text.trim()) ?? 0;
      if (years == 0 && months == 0) return (null, false);

      final today = DateTime.now();
      int m = today.month - months;
      int y = today.year - years;
      while (m <= 0) {
        m += 12;
        y -= 1;
      }
      final d = today.day.clamp(1, DateTime(y, m + 1, 0).day);
      return (_dateStr(DateTime(y, m, d)), true);
    } else {
      if (_birthdate == null) return (null, false);
      return (_dateStr(_birthdate!), true);
    }
  }

  static String _dateStr(DateTime dt) =>
      "${dt.year.toString().padLeft(4, '0')}-"
      "${dt.month.toString().padLeft(2, '0')}-"
      "${dt.day.toString().padLeft(2, '0')}";

  Future<void> _submit() async {
    setState(() => _triedSubmit = true);

    final formValid = _formKey.currentState?.validate() ?? false;
    final (birthdateStr, birthdateValid) = _computeBirthdate();
    setState(() => _birthdateError = birthdateValid ? null : "Required");

    if (!formValid || !_spayedAnswered || !birthdateValid) return;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final body = <String, dynamic>{
        "name": _nameCtrl.text.trim(),
        "species": _species,
        "breed_text": _breedCtrl.text.trim(),
        "sex": _sex,
        "spayed_neutered": _spayedNeutered,
        "birthdate": birthdateStr,
      };

      final weightText = _weightCtrl.text.trim();
      if (weightText.isNotEmpty) body["weight_kg"] = weightText;

      Map<String, dynamic> result;
      if (_isEdit) {
        result = await PetsApi.updatePet(
          petId: widget.pet!["id"] as int,
          body: body,
        );
      } else {
        result = await PetsApi.createPet(body: body);
        if (_pendingPhoto != null) {
          try {
            result = await PetsApi.uploadPetPhoto(
              result["id"] as int,
              _pendingPhoto!.path,
              mimeType: _pendingPhoto!.mimeType ?? 'image/jpeg',
            );
          } catch (_) {
            // Non-fatal: pet was created, photo just didn't upload
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.toString();
        _isSaving = false;
      });
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete pet?"),
        content: const Text(
          "This action cannot be undone. All data for this pet will be permanently deleted.",
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

    setState(() {
      _isDeleting = true;
      _errorText = null;
    });

    try {
      await PetsApi.deletePet(widget.pet!["id"] as int);
      if (!mounted) return;
      Navigator.of(context).pop({"__deleted": true});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.toString();
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          _isEdit ? "Edit pet" : "Add a new pet",
          style: const TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: muted),
        actions: _isEdit
            ? [
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    "Delete pet",
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: _busy ? null : _handleDelete,
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(child: _photoAvatar()),
              const SizedBox(height: 20),
              _labeledField("Name", _nameCtrl, required: true),
              const SizedBox(height: 16),
              if (_isEdit)
                _labeledReadOnly("Species", _speciesDisplayName(_species))
              else
                _labeledDropdown(
                  "Species",
                  _species,
                  const [
                    DropdownMenuItem(value: "cat", child: Text("Cat")),
                    DropdownMenuItem(value: "dog", child: Text("Dog")),
                  ],
                  onChanged: (v) => setState(() => _species = v),
                  required: true,
                ),
              const SizedBox(height: 16),
              _labeledField("Breed", _breedCtrl, required: true),
              const SizedBox(height: 16),
              _labeledDropdown(
                "Sex",
                _sex,
                const [
                  DropdownMenuItem(value: "male", child: Text("Male")),
                  DropdownMenuItem(value: "female", child: Text("Female")),
                  DropdownMenuItem(value: "unknown", child: Text("Unknown")),
                ],
                onChanged: (v) => setState(() => _sex = v),
                required: true,
              ),
              const SizedBox(height: 16),
              _spayedNeuteredField(),
              const SizedBox(height: 16),
              _birthdateSection(),
              const SizedBox(height: 16),
              _labeledField(
                "Weight (kg)",
                _weightCtrl,
                hint: "Optional",
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: titleColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const _LoadingIndicator(color: Colors.white)
                    : Text(
                        _isEdit ? "Save changes" : "Add pet",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: muted,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "Discard changes",
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoAvatar() {
    const double radius = 52;
    final ImageProvider? imageProvider = _pendingPhoto != null
        ? FileImage(File(_pendingPhoto!.path))
        : _photoUrl.isNotEmpty
        ? NetworkImage(_photoUrl)
        : null;

    return GestureDetector(
      onTap: _uploadingPhoto ? null : _pickPhoto,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? const Icon(Icons.pets, size: 40, color: Colors.white)
                : null,
          ),
          if (_uploadingPhoto)
            Positioned.fill(
              child: CircleAvatar(
                radius: radius,
                backgroundColor: Colors.black45,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: titleColor,
              child: const Icon(
                Icons.camera_alt,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _spayedNeuteredField() {
    return _chipField(
      label: "Spayed / Neutered *",
      showError: _triedSubmit && !_spayedAnswered,
      chips: Row(
        children: [
          _selectChip(
            "Yes",
            selected: _spayedAnswered && _spayedNeutered == true,
            onTap: () => setState(() {
              _spayedNeutered = true;
              _spayedAnswered = true;
            }),
          ),
          const SizedBox(width: 10),
          _selectChip(
            "No",
            selected: _spayedAnswered && _spayedNeutered == false,
            onTap: () => setState(() {
              _spayedNeutered = false;
              _spayedAnswered = true;
            }),
          ),
          const SizedBox(width: 10),
          _selectChip(
            "Unknown",
            selected: _spayedAnswered && _spayedNeutered == null,
            onTap: () => setState(() {
              _spayedNeutered = null;
              _spayedAnswered = true;
            }),
          ),
        ],
      ),
    );
  }

  Widget _birthdateSection() {
    return _chipField(
      label: "Birthdate *",
      showError: _triedSubmit && _birthdateError != null,
      chips: Row(
        children: [
          _selectChip(
            "Exact date",
            selected: !_useBirthdateApprox,
            onTap: () {
              if (!_useBirthdateApprox) return;
              // Sync approx → exact: estimate birthdate from entered years/months
              final years = int.tryParse(_approxYearsCtrl.text.trim()) ?? 0;
              final months = int.tryParse(_approxMonthsCtrl.text.trim()) ?? 0;
              if (years > 0 || months > 0) {
                final today = DateTime.now();
                int m = today.month - months;
                int y = today.year - years;
                while (m <= 0) {
                  m += 12;
                  y -= 1;
                }
                final d = today.day.clamp(1, DateTime(y, m + 1, 0).day);
                setState(() {
                  _birthdate = DateTime(y, m, d);
                  _useBirthdateApprox = false;
                });
              } else {
                setState(() => _useBirthdateApprox = false);
              }
            },
          ),
          const SizedBox(width: 10),
          _selectChip(
            "Approximate age",
            selected: _useBirthdateApprox,
            onTap: () {
              if (_useBirthdateApprox) return;
              // Sync exact → approx: calculate age from selected birthdate
              if (_birthdate != null) {
                final today = DateTime.now();
                int totalMonths =
                    (today.year - _birthdate!.year) * 12 +
                    (today.month - _birthdate!.month);
                if (today.day < _birthdate!.day) totalMonths--;
                if (totalMonths < 0) totalMonths = 0;
                _approxYearsCtrl.text = (totalMonths ~/ 12).toString();
                _approxMonthsCtrl.text = (totalMonths % 12).toString();
              }
              setState(() => _useBirthdateApprox = true);
            },
          ),
        ],
      ),
      extra: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _useBirthdateApprox ? _approxAgeInput() : _exactDateInput(),
      ),
    );
  }

  Widget _exactDateInput() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _birthdate ?? DateTime.now(),
          firstDate: DateTime(1980),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            _birthdate = picked;
            _birthdateError = null;
          });
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _birthdate != null ? _formatBirthdate(_birthdate!) : "Tap to select",
          style: TextStyle(
            fontSize: 15,
            color: _birthdate != null ? muted : const Color(0xFFAAAAAA),
          ),
        ),
      ),
    );
  }

  Widget _approxAgeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _approxField(_approxYearsCtrl, "years"),
            const SizedBox(width: 16),
            _approxField(_approxMonthsCtrl, "months"),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "Birthdate will be estimated from today",
          style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
        ),
      ],
    );
  }

  Widget _approxField(TextEditingController ctrl, String label) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: muted),
          ),
        ),
      ],
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _chipField({
    required String label,
    required bool showError,
    required Widget chips,
    Widget? extra,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 6),
        chips,
        if (extra != null) extra,
        if (showError)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              "Required",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _selectChip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? titleColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: _chipShadow,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : muted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Text _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: muted,
    ),
  );

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );

  Widget _labeledField(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(required ? "$label *" : label),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: _inputDecoration(hint: hint),
          validator:
              validator ??
              (required
                  ? (v) => (v == null || v.trim().isEmpty) ? "Required" : null
                  : null),
        ),
      ],
    );
  }

  Widget _labeledReadOnly(String label, String displayValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            displayValue,
            style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _labeledDropdown(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items, {
    required void Function(String?) onChanged,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(required ? "$label *" : label),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          decoration: _inputDecoration(),
          validator: required ? (v) => v == null ? "Required" : null : null,
        ),
      ],
    );
  }

  static String _speciesDisplayName(String? species) => switch (species) {
    "cat" => "Cat",
    "dog" => "Dog",
    _ => species ?? "—",
  };

  static String _formatBirthdate(DateTime dt) {
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
  }
}

class _LoadingIndicator extends StatelessWidget {
  final Color color;
  const _LoadingIndicator({required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 18,
    width: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );
}
