import 'package:flutter/material.dart';
import '../../services/pets_api.dart';
import '../../services/pet_store.dart';
import '../../services/token_store.dart';
import '../assessment/assessment_page.dart';
import 'package:frontend/state/notifiers.dart';
import 'package:frontend/models/pet.dart';
import '../../services/assessment_api.dart';
import '../assessment/assessment_results.dart';
import '../assessment/assessment_history.dart';
import 'pet_form_page.dart';
import 'pet_detail_page.dart';

class MypetPage extends StatefulWidget {
  const MypetPage({super.key});

  @override
  State<MypetPage> createState() => _MypetPageState();
}

class _MypetPageState extends State<MypetPage> {
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);

  bool isLoading = true;
  String? errorText;

  List<Map<String, dynamic>> pets = [];
  final Map<int, Map<String, dynamic>?> _assessmentsByPet = {};
  final Set<int> _loadingAssessmentPetIds = {};

  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadPets();
    selectedPetNotifier.addListener(_onSelectedPetChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    selectedPetNotifier.removeListener(_onSelectedPetChanged);
    super.dispose();
  }

  void _onSelectedPetChanged() {
    if (!mounted) return;
    final selectedId = selectedPetNotifier.value?.id;
    if (selectedId == null) return;
    PetStore.setCurrentPetId(selectedId);
    // Animate carousel to the matching page (if triggered by the app-bar dropdown)
    final index = pets.indexWhere((p) => (p["id"] as int?) == selectedId);
    if (index >= 0 && _pageController.hasClients) {
      final currentPage = _pageController.page?.round() ?? 0;
      if (currentPage != index) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
    setState(() {});
    if (!_assessmentsByPet.containsKey(selectedId)) {
      _loadLatestAssessment(selectedId);
    }
  }

  void _onPageChanged(int index) {
    if (index >= pets.length) return;
    final petId = pets[index]["id"] as int;
    final model = petsNotifier.value.firstWhere(
      (p) => p.id == petId,
      orElse: () => petsNotifier.value.first,
    );
    selectedPetNotifier.value = model;
    PetStore.setCurrentPetId(petId);
    if (!_assessmentsByPet.containsKey(petId)) {
      _loadLatestAssessment(petId);
    }
    setState(() {}); // rebuild dots
  }

  Future<void> _loadPets() async {
    _assessmentsByPet.clear();
    _loadingAssessmentPetIds.clear();

    try {
      final access = await TokenStore.readAccess();
      if (access == null) throw "No access token found.";

      final petList = await PetsApi.listPets();

      if (!mounted) return;

      setState(() {
        pets = petList;
        isLoading = false;
      });

      // Sync the app-shell notifiers with the real pet list
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

      // Always refresh selectedPetNotifier from the new list so photoUrl etc. stay current
      final currentId = selectedPetNotifier.value?.id;
      final refreshed = currentId != null
          ? petModels.where((p) => p.id == currentId).firstOrNull
          : null;
      if (refreshed != null) {
        selectedPetNotifier.value = refreshed;
      } else if (petModels.isNotEmpty) {
        selectedPetNotifier.value = petModels.first;
      }

      // Jump the carousel to the selected pet and load its assessment
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final selId = selectedPetNotifier.value?.id;
        final index = pets.indexWhere((p) => (p["id"] as int?) == selId);
        if (index > 0 && _pageController.hasClients) {
          _pageController.jumpToPage(index);
        }
        if (selId != null && !_assessmentsByPet.containsKey(selId)) {
          _loadLatestAssessment(selId);
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadLatestAssessment(int petId) async {
    if (!mounted) return;
    setState(() => _loadingAssessmentPetIds.add(petId));

    try {
      final assessment = await AssessmentApi.getLatestAssessment(petId: petId);
      if (!mounted) return;
      setState(() {
        _assessmentsByPet[petId] = assessment;
        _loadingAssessmentPetIds.remove(petId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _assessmentsByPet[petId] = null;
        _loadingAssessmentPetIds.remove(petId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        color: bg,
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorText != null
              ? Center(
                  child: Text(
                    errorText!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : _content(),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: const Text(
            "My pets",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (pets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _emptyPetCard(),
          )
        else ...[
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.48,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: pets.length,
              itemBuilder: (context, index) {
                final pet = pets[index];
                final petId = pet["id"] as int;
                final assessment = _assessmentsByPet[petId];
                final isLoading = _loadingAssessmentPetIds.contains(petId);
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      _petCard(pet),
                      const SizedBox(height: 14),
                      _historyCard(pet, assessment, isLoading),
                      const SizedBox(height: 8),
                      _buildHistoryLink(pet),
                    ],
                  ),
                );
              },
            ),
          ),
          if (pets.length > 1) ...[
            const SizedBox(height: 10),
            _dotIndicators(),
          ],
        ],
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "More actions",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              const SizedBox(height: 5),
              _actionRow(
                Icons.add_circle_outline,
                "Add a new pet",
                onTap: _handleAddNewPet,
              ),
              _actionRow(
                Icons.group_outlined,
                "Add a family member",
                onTap: () {},
              ),
              _actionRow(
                Icons.add_circle_outline,
                "Take a new test",
                onTap: _handleTakeNewTest,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dotIndicators() {
    final currentPage = _pageController.hasClients
        ? (_pageController.page?.round() ?? 0)
        : 0;

    if (pets.length > 8) {
      return Text(
        "${currentPage + 1} / ${pets.length}",
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: muted,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pets.length, (index) {
        final active = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? titleColor : const Color(0xFFCCB9AD),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          blurRadius: 12,
          offset: Offset(0, 6),
          color: Color(0x22000000),
        ),
      ],
    );
  }

  Widget _emptyPetCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: const Text(
        "No pets yet. Add a new pet to get started.",
        style: TextStyle(color: muted),
      ),
    );
  }

  Widget _petPhoto(String? photoUrl, {required double size}) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.grey.shade300,
      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
          ? NetworkImage(photoUrl)
          : null,
      child: (photoUrl == null || photoUrl.isEmpty)
          ? Icon(Icons.pets, color: muted, size: size * 0.45)
          : null,
    );
  }

  Widget _petCard(Map<String, dynamic> pet) {
    final petName = (pet["name"] ?? "").toString();
    final breed = (pet["breed_text"] ?? "").toString().trim();
    final species = (pet["species"] ?? "").toString().trim();
    final sex = (pet["sex"] ?? "").toString().trim();
    final infoLines = <String>[
      if (breed.isNotEmpty) breed,
      if (species.isNotEmpty) species,
      if (sex.isNotEmpty) sex,
    ];

    return GestureDetector(
      onTap: () => _handleSeePetDetails(pet),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _petPhoto(pet["photo_url"]?.toString(), size: 82),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        petName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final line in infoLines)
                        Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFEEE8E2)),
            const SizedBox(height: 10),
            _petCardRow("Favorite Foods", "—"),
            const SizedBox(height: 6),
            _petCardRow("Favorite Activities", "—"),
            const SizedBox(height: 6),
            _petCardRow("Medication history", "—"),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "See more →",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _petCardRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: muted),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  int _readScore(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic>? _assessmentAnswers(Map<String, dynamic>? assessment) {
    if (assessment == null) return null;

    final raw = assessment["answers"];
    if (raw is Map<String, dynamic>) return raw;

    return null;
  }

  List<AssessmentScaleScore> _buildScaleScores(
    Map<String, dynamic>? assessment,
  ) {
    final answers = _assessmentAnswers(assessment);
    if (answers == null) return const [];

    final fields = <MapEntry<String, String>>[
      const MapEntry("Appetite", "appetite_score"),
      const MapEntry("Hydration", "hydration_score"),
      const MapEntry("Cleanliness", "cleanliness_score"),
      const MapEntry("Mobility", "mobility_score"),
      const MapEntry("Physical Comfort", "physical_score"),
      const MapEntry("State of Mind", "state_of_mind_score"),
      const MapEntry("Owner State", "owner_state_score"),
    ];

    return fields
        .map(
          (e) => AssessmentScaleScore(
            label: e.key,
            score: _readScore(answers[e.value]),
          ),
        )
        .toList();
  }

  Widget _historyCard(
    Map<String, dynamic>? pet,
    Map<String, dynamic>? assessment,
    bool isLoadingAssessment,
  ) {
    final heartScore = assessment?["heart_score"];
    final conditionScore = assessment?["condition_score"];
    final assessedAtRaw = assessment?["submitted_at"];
    final assessedAtText = _formatAssessmentDate(assessedAtRaw);
    final petName = (pet?["name"] ?? "").toString().trim();
    final hasAssessment = assessment != null;
    final scaleScores = _buildScaleScores(assessment);
    final petId = pet?["id"] as int?;

    return GestureDetector(
      onTap: !hasAssessment
          ? null
          : () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AssessmentResultsPage(
                    petName: petName.isEmpty ? "Your pet" : petName,
                    heartScore: heartScore,
                    conditionScore: conditionScore,
                    significantlyChallenged: _hasSignificantlyChallengedFlag(
                      assessment,
                    ),
                    scaleScores: scaleScores,
                    onDone: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              );
              if (petId != null && mounted) {
                _assessmentsByPet.remove(petId);
                _loadLatestAssessment(petId);
              }
            },
      child: Opacity(
        opacity: hasAssessment ? 1.0 : 0.75,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                child: Text(
                  isLoadingAssessment
                      ? "Loading..."
                      : (assessedAtText ?? "No recent\nassessment"),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 16,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: const [
                        Expanded(
                          child: Text(
                            "heart",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "condition",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: muted,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            heartScore?.toString() ?? "—",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            conditionScore?.toString() ?? "—",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                hasAssessment ? Icons.chevron_right : Icons.remove,
                color: muted,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryLink(Map<String, dynamic>? pet) {
    if (pet == null) return const SizedBox.shrink();

    final petId = pet["id"] as int?;
    final petName = (pet["name"] ?? "").toString().trim();

    if (petId == null) return const SizedBox.shrink();

    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AssessmentHistoryPage(
                petId: petId,
                petName: petName.isEmpty ? "Your pet" : petName,
              ),
            ),
          );

          if (!mounted) return;
          await _loadLatestAssessment(petId);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: const Text(
            "See previous assessments",
            style: TextStyle(
              fontSize: 14,
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String? _formatAssessmentDate(dynamic raw) {
    if (raw == null) return null;

    try {
      final dt = DateTime.parse(raw.toString()).toLocal();

      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];

      final month = months[dt.month - 1];
      final day = _ordinal(dt.day);

      return "$month $day\n${dt.year}";
    } catch (_) {
      return null;
    }
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return "${day}th";

    switch (day % 10) {
      case 1:
        return "${day}st";
      case 2:
        return "${day}nd";
      case 3:
        return "${day}rd";
      default:
        return "${day}th";
    }
  }

  Widget _actionRow(
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 20,
      leading: Icon(icon, size: 20, color: muted),
      title: Text(label, style: const TextStyle(fontSize: 18, color: muted)),
      onTap: onTap,
    );
  }

  Future<void> _handleAddNewPet() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const PetFormPage()),
    );
    if (!mounted || result == null) return;
    final newId = result["id"] as int?;
    await _loadPets();
    // Select the newly created pet
    if (!mounted || newId == null) return;
    final newPet = petsNotifier.value.firstWhere(
      (p) => p.id == newId,
      orElse: () => petsNotifier.value.first,
    );
    selectedPetNotifier.value = newPet;
  }

  Future<void> _handleSeePetDetails(Map<String, dynamic> pet) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PetDetailPage(pet: pet)));
    if (!mounted) return;
    await _loadPets();
  }

  Future<void> _handleTakeNewTest() async {
    if (pets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please add a pet first.")));
      return;
    }

    // Use the currently displayed pet if available
    final selectedId = selectedPetNotifier.value?.id;
    if (selectedId != null) {
      final currentPet = pets.firstWhere(
        (p) => (p["id"] as int?) == selectedId,
        orElse: () => pets.first,
      );
      await _startAssessmentForPet(currentPet);
      return;
    }

    if (pets.length == 1) {
      await _startAssessmentForPet(pets.first);
      return;
    }

    final selectedPet = await _pickPetForAssessment();
    if (selectedPet == null || !mounted) return;

    await _startAssessmentForPet(selectedPet);
  }

  Future<void> _startAssessmentForPet(Map<String, dynamic> pet) async {
    final petId = pet["id"] as int;
    final petName = (pet["name"] ?? "").toString().trim();
    final ownerName = userNotifier.value?.name;

    if (!mounted) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssessmentPage(
          petId: petId,
          petName: petName.isEmpty ? "Your pet" : petName,
          ownerName: ownerName ?? "Owner",
        ),
      ),
    );

    if (!mounted) return;

    // refresh latest assessment after coming back
    await _loadLatestAssessment(petId);

    // optional: if AssessmentPage returns something useful later,
    // you can use `result` here
    debugPrint("AssessmentPage returned: $result");
  }

  Future<Map<String, dynamic>?> _pickPetForAssessment() async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: const Text(
                  "Select a pet",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  shrinkWrap: true,
                  children: pets.map((pet) {
                    final petName = (pet["name"] ?? "").toString().trim();
                    final breed = (pet["breed_text"] ?? "").toString().trim();
                    final species = (pet["species"] ?? "").toString().trim();

                    final subtitle = [
                      if (breed.isNotEmpty) breed,
                      if (species.isNotEmpty) species,
                    ].join(" • ");

                    final photoUrl = pet["photo_url"]?.toString();
                    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: hasPhoto
                            ? NetworkImage(photoUrl)
                            : null,
                        child: hasPhoto
                            ? null
                            : const Icon(Icons.pets, color: muted),
                      ),
                      title: Text(
                        petName.isEmpty ? "Unnamed pet" : petName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: subtitle.isEmpty
                          ? null
                          : Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: muted),
                            ),
                      trailing: const Icon(Icons.chevron_right, color: muted),
                      onTap: () => Navigator.of(context).pop(pet),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _hasSignificantlyChallengedFlag(Map<String, dynamic>? assessment) {
    final value = assessment?["significantly_challenged"];

    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == "true";
    if (value is int) return value == 1;

    return false;
  }
}
