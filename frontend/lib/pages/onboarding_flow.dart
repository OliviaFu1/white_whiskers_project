import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'onboarding_widget.dart';
import '../services/auth_api.dart';
import '../services/token_store.dart';

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

  String? sex;
  String? species;
  final breed = TextEditingController();

  // use a non-null default for wheel stability
  int ageYears = 0;
  DateTime? birthDate;

  bool _ownerTouched = false;
  bool _petTouched = false;

  // save name on step 0
  bool _savingName = false;
  String? _nameSaveError;

  // final submit
  bool _savingFinal = false;
  String? _finalError;

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

      // create pet
      final petBody = <String, dynamic>{
        "name": petName.text.trim(),
        // species is required by your model; ensure you send something
        "species": (species ?? "dog"),
        // sex has a default in backend, but it's fine to send
        "sex": (sex ?? "unknown"),
        // optional fields: only include if non-empty
        if (breed.text.trim().isNotEmpty) "breed_text": breed.text.trim(),
        if (birthDate != null)
          "birthdate": birthDate!
              .toIso8601String()
              .split('T')
              .first, // YYYY-MM-DD
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

  bool get _ownerValid => ownerName.text.trim().isNotEmpty;
  bool get _petValid => petName.text.trim().isNotEmpty;

  String get _petLabel =>
      petName.text.trim().isEmpty ? "your pet" : petName.text.trim();

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
          onSkip: null,
          helperError:
              _nameSaveError ??
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
          onSkip: null,
          helperError: (_petTouched && !_petValid)
              ? "Pet name is required"
              : null,
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
          canNext: true,
          onNext: _next,
          onSkip: null,
          helperError: null,
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: UnderlineDropdownInput<String>(
            label: "Species",
            value: species,
            lineColor: muted,
            onChanged: (v) => setState(() => species = v),
            items: const [
              DropdownMenuItem(value: "dog", child: Text("Dog")),
              DropdownMenuItem(value: "cat", child: Text("Cat")),
              DropdownMenuItem(value: "other", child: Text("Other")),
            ],
          ),
        ),

        // 3) sex (optional)
        OnboardingStepScaffold(
          title: "Great!\nWhat’s $_petLabel’s sex?",
          showBack: true,
          onBack: _back,
          canNext: true,
          onNext: _next,
          onSkip: _next,
          helperError: null,
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: UnderlineDropdownInput<String>(
            label: "Sex",
            value: sex,
            lineColor: muted,
            onChanged: (v) => setState(() => sex = v),
            items: const [
              DropdownMenuItem(value: "male", child: Text("Male")),
              DropdownMenuItem(value: "female", child: Text("Female")),
              DropdownMenuItem(
                value: "unknown",
                child: Text("Prefer not to say"),
              ),
            ],
          ),
        ),

        // 4) breed (optional text)
        OnboardingStepScaffold(
          title: "What breed is $_petLabel?",
          showBack: true,
          onBack: _back,
          canNext: true,
          onNext: _next,
          onSkip: _next,
          helperError: null,
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: UnderlineTextInput(
            controller: breed,
            label: "Breed",
            lineColor: muted,
            onChanged: (_) => setState(() {}),
          ),
        ),

        // 5) age (optional scrolling wheel)
        OnboardingStepScaffold(
          title: "How old is $_petLabel?",
          showBack: true,
          onBack: _back,
          canNext: true,
          onNext: _next,
          onSkip: _next,
          helperError: null,
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: AgeWheelPicker(
            value: ageYears,
            lineColor: muted,
            onChanged: (v) => setState(() => ageYears = v),
          ),
        ),

        // 6) birth date (optional date picker)
        OnboardingStepScaffold(
          title: "Birthdate of $_petLabel",
          showBack: true,
          onBack: _back,
          canNext: true,
          onNext: _next, // <-- go to "All set" page
          onSkip: _next, // <-- skip birthdate, still go to "All set"
          helperError: null,
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: _BirthDateField(
            muted: muted,
            selected: birthDate,
            onPick: (d) => setState(() => birthDate = d),
          ),
        ),

        // 7) final "All Set" page
        OnboardingStepScaffold(
          title: "You’re All Set!\nReady to take your\nfirst assessment?",
          showBack: true,
          onBack: _back,

          canNext: false,
          onNext: null,
          onSkip: null,

          helperError: _finalError,
          bg: bg,
          titleColor: titleColor,
          accent: accent,
          muted: muted,
          field: Column(
            children: [
              GestureDetector(
                onTap: _savingFinal
                    ? null
                    : () => _finalizeAndGo('/assessment'),
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
          children: List.generate(21, (i) => Center(child: Text("$i"))),
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
