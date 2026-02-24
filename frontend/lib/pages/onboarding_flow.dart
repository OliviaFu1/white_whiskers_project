import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'onboarding_widget.dart';
import '../services/auth_api.dart';
import '../services/token_store.dart';

enum AgeInputMode { age, birthdate }

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const bg = Color(0xFFFBF2EB);
  static const titleColor = Color(0xFFD88442);
  static const accent = Color(0xFF917869);
  static const muted = Color(0xFF676767);

  final _controller = PageController();
  int _page = 0;

  // answers
  final ownerName = TextEditingController();
  final petName = TextEditingController();

  String? species;
  String? sex;
  bool? spayedNeutered;
  final breed = TextEditingController();

  // Age/Birthdate
  AgeInputMode? ageMode; // user must pick first
  int ageYears = 0; // wheel stability
  DateTime? birthDate;

  // touched flags for errors
  bool _ownerTouched = false;
  bool _petTouched = false;
  bool _speciesTouched = false;
  bool _sexTouched = false;
  bool _spayTouched = false;
  bool _breedTouched = false;
  bool _ageModeTouched = false;
  bool _ageValueTouched = false;

  // save name on step 0
  bool _savingName = false;
  String? _nameSaveError;

  // final submit
  bool _savingFinal = false;
  String? _finalError;

  // ---------------------------
  // Validation getters
  // ---------------------------
  bool get _ownerValid => ownerName.text.trim().isNotEmpty;
  bool get _petValid => petName.text.trim().isNotEmpty;

  bool get _speciesValid => species != null;
  bool get _sexValid => sex != null;
  bool get _spayedValid => spayedNeutered != null;
  bool get _breedValid => breed.text.trim().isNotEmpty;

  bool get _ageModeValid => ageMode != null;

  bool get _ageValueValid {
    if (ageMode == null) return false;
    if (ageMode == AgeInputMode.age) {
      return true;
    } else {
      return birthDate != null;
    }
  }

  String get _petLabel =>
      petName.text.trim().isEmpty ? "your pet" : petName.text.trim();

  // ---------------------------
  // Actions
  // ---------------------------
  Future<void> _saveNameAndNext() async {
    if (_savingName) return;

    setState(() {
      _savingName = true;
      _nameSaveError = null;
    });

    try {
      final access = await TokenStore.readAccess();
      if (access == null) throw "Session expired. Please log in again.";

      await AuthApi.updateMe(accessToken: access, name: ownerName.text.trim());

      if (!mounted) return;
      setState(() => _savingName = false);
      _next();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingName = false;
        _nameSaveError = e.toString();
      });
    }
  }

  Future<void> _finalizeAndGo(String route) async {
    if (_savingFinal) return;

    setState(() {
      _savingFinal = true;
      _finalError = null;
    });

    try {
      final access = await TokenStore.readAccess();
      if (access == null) throw "No access token found.";

      final petBody = <String, dynamic>{
        "name": petName.text.trim(),
        "species": species,
        "sex": sex,
        "spayed_neutered": spayedNeutered,
        "breed_text": breed.text.trim(),
        if (ageMode == AgeInputMode.age) "age_years": ageYears,
        if (ageMode == AgeInputMode.birthdate && birthDate != null)
          "birthdate": birthDate!.toIso8601String().split('T').first,
      };

      await AuthApi.createPet(accessToken: access, body: petBody);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingFinal = false;
        _finalError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    ownerName.dispose();
    petName.dispose();
    breed.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    _controller.animateToPage(
      _page + 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    FocusScope.of(context).unfocus();
    _controller.animateToPage(
      _page - 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (i) => setState(() => _page = i),
      children: [
        // 0) owner name (required)
        OnboardingStepScaffold(
          title: "What’s your name?",
          showBack: false,
          onBack: null,
          canNext: _ownerValid,
          onNext: _saveNameAndNext,
          helperError: _nameSaveError ??
              ((_ownerTouched && !_ownerValid) ? "Name is required" : null),
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: UnderlineTextInput(
            controller: ownerName,
            label: "Name",
            lineColor: muted,
            onChanged: (_) => setState(() => _ownerTouched = true),
          ),
        ),

        // 1) pet name (required)
        OnboardingStepScaffold(
          title:
              "Hello ${ownerName.text.trim().isEmpty ? "" : "${ownerName.text.trim()}!"}\nWhat’s your pet’s name?",
          showBack: true,
          onBack: _back,
          canNext: _petValid,
          onNext: _next,
          helperError: (_petTouched && !_petValid) ? "Pet name is required" : null,
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: UnderlineTextInput(
            controller: petName,
            label: "Pet’s Name",
            lineColor: muted,
            onChanged: (_) => setState(() => _petTouched = true),
          ),
        ),

        // 2) species (required)
        OnboardingStepScaffold(
          title: "What species is $_petLabel?",
          showBack: true,
          onBack: _back,
          canNext: _speciesValid,
          onNext: _next,
          helperError:
              (_speciesTouched && !_speciesValid) ? "Species is required" : null,
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: UnderlineDropdownInput<String>(
            label: "Species",
            value: species,
            lineColor: muted,
            onChanged: (v) => setState(() {
              _speciesTouched = true;
              species = v;
            }),
            items: const [
              DropdownMenuItem(value: "dog", child: Text("Dog")),
              DropdownMenuItem(value: "cat", child: Text("Cat")),
            ],
          ),
        ),

        // 3) sex + spayed/neutered (both required)
        OnboardingStepScaffold(
          title: "Great!\nTell us about $_petLabel",
          showBack: true,
          onBack: _back,
          canNext: _sexValid && _spayedValid,
          onNext: _next,
          helperError: (!_sexValid && _sexTouched)
              ? "Sex is required"
              : ((!_spayedValid && _spayTouched)
                  ? "Please select spayed/neutered"
                  : null),
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: SexAndSpayField(
            sexValue: sex,
            onSexChanged: (v) => setState(() {
              _sexTouched = true;
              sex = v;
            }),
            spayedValue: spayedNeutered,
            onSpayedChanged: (v) => setState(() {
              _spayTouched = true;
              spayedNeutered = v;
            }),
            muted: muted,
          ),
        ),

        // 4) breed (required)
        OnboardingStepScaffold(
          title: "What breed is $_petLabel?",
          showBack: true,
          onBack: _back,
          canNext: _breedValid,
          onNext: _next,
          helperError: (_breedTouched && !_breedValid) ? "Breed is required" : null,
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: UnderlineTextInput(
            controller: breed,
            label: "Breed",
            lineColor: muted,
            onChanged: (_) => setState(() => _breedTouched = true),
          ),
        ),

        // 5) age OR birthdate
        OnboardingStepScaffold(
          title: "How old is $_petLabel?",
          showBack: true,
          onBack: _back,
          canNext: _ageModeValid && _ageValueValid,
          onNext: _next,
          helperError: (!_ageModeValid && _ageModeTouched)
              ? "Please choose Age or Birthdate"
              : ((!_ageValueValid && _ageValueTouched)
                  ? (ageMode == AgeInputMode.birthdate
                      ? "Birthdate is required"
                      : "Age is required")
                  : null),
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: AgeOrBirthdateField(
            mode: ageMode,
            muted: muted,
            ageYears: ageYears,
            birthDate: birthDate,
            onModeChanged: (m) => setState(() {
              _ageModeTouched = true;
              ageMode = m;
              // clear the other input for clarity
              if (ageMode == AgeInputMode.age) {
                birthDate = null;
              }
              _ageValueTouched = false;
            }),
            onAgeChanged: (v) => setState(() {
              _ageValueTouched = true;
              ageYears = v;
            }),
            onBirthPick: (d) => setState(() {
              _ageValueTouched = true;
              birthDate = d;
            }),
          ),
        ),

        // 6) final page
        OnboardingStepScaffold(
          title: "You’re All Set!\nReady to take your\nfirst assessment?",
          showBack: true,
          onBack: _back,
          canNext: false,
          onNext: null,
          helperError: _finalError,
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: Column(
            children: [
              GestureDetector(
                onTap:
                    _savingFinal ? null : () => _finalizeAndGo('/assessment'),
                child: Text(
                  _savingFinal ? "saving..." : "start first assessment",
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    fontSize: 14,
                    color: muted,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _savingFinal ? null : () => _finalizeAndGo('/mypets'),
                child: Text(
                  _savingFinal ? "saving..." : "Homepage",
                  style: const TextStyle(
                    decoration: TextDecoration.underline,
                    fontSize: 12,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------
// Specific widgets
// ---------------------------

class SexAndSpayField extends StatelessWidget {
  final String? sexValue;
  final ValueChanged<String?> onSexChanged;

  final bool? spayedValue;
  final ValueChanged<bool?> onSpayedChanged;

  final Color muted;

  const SexAndSpayField({
    super.key,
    required this.sexValue,
    required this.onSexChanged,
    required this.spayedValue,
    required this.onSpayedChanged,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UnderlineDropdownInput<String>(
          label: "Sex",
          value: sexValue,
          lineColor: muted,
          onChanged: onSexChanged,
          items: const [
            DropdownMenuItem(value: "male", child: Text("Male")),
            DropdownMenuItem(value: "female", child: Text("Female")),
            DropdownMenuItem(value: "unknown", child: Text("Prefer not to say")),
          ],
        ),
        const SizedBox(height: 18),
        Text("Spayed / Neutered",
            style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            ChoiceChip(
              label: const Text("Yes"),
              selected: spayedValue == true,
              onSelected: (_) => onSpayedChanged(true),
            ),
            ChoiceChip(
              label: const Text("No"),
              selected: spayedValue == false,
              onSelected: (_) => onSpayedChanged(false),
            ),
          ],
        ),
      ],
    );
  }
}

class AgeOrBirthdateField extends StatelessWidget {
  final AgeInputMode? mode;
  final ValueChanged<AgeInputMode> onModeChanged;

  final int ageYears;
  final ValueChanged<int> onAgeChanged;

  final DateTime? birthDate;
  final ValueChanged<DateTime?> onBirthPick;

  final Color muted;

  const AgeOrBirthdateField({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.ageYears,
    required this.onAgeChanged,
    required this.birthDate,
    required this.onBirthPick,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // user must choose first
        Wrap(
          spacing: 10,
          children: [
            ChoiceChip(
              label: const Text("Enter age"),
              selected: mode == AgeInputMode.age,
              onSelected: (_) => onModeChanged(AgeInputMode.age),
            ),
            ChoiceChip(
              label: const Text("Pick birthdate"),
              selected: mode == AgeInputMode.birthdate,
              onSelected: (_) => onModeChanged(AgeInputMode.birthdate),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (mode == null)
          Text(
            "Choose one option above.",
            style: TextStyle(color: muted, fontSize: 12),
          )
        else if (mode == AgeInputMode.age)
          AgeWheelPicker(
            value: ageYears,
            lineColor: muted,
            onChanged: onAgeChanged,
          )
        else
          _BirthDateField(
            muted: muted,
            selected: birthDate,
            onPick: onBirthPick,
          ),
      ],
    );
  }
}

class AgeWheelPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final Color lineColor;
  final String label;

  const AgeWheelPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.lineColor,
    this.label = "Age (years)",
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: lineColor),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: lineColor, width: 1.2),
        ),
      ),
      child: SizedBox(
        height: 140,
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(initialItem: value),
          itemExtent: 34,
          onSelectedItemChanged: onChanged,
          children: List.generate(41, (i) => Center(child: Text("$i"))),
        ),
      ),
    );
  }
}

class _BirthDateField extends StatelessWidget {
  final Color muted;
  final DateTime? selected;
  final ValueChanged<DateTime?> onPick;

  const _BirthDateField({
    required this.muted,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final text = selected == null
        ? "Select date"
        : "${selected!.year}-${selected!.month.toString().padLeft(2, '0')}-${selected!.day.toString().padLeft(2, '0')}";

    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: selected ?? DateTime(now.year - 1, now.month, now.day),
          firstDate: DateTime(1990),
          lastDate: now,
        );
        onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: "Birthdate",
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: muted),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: muted, width: 1.2),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}