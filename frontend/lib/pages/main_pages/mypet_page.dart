import 'package:flutter/material.dart';
import '../../services/pets_api.dart';
import '../../services/pet_store.dart';
import '../../services/token_store.dart';
import '../assessment/assessment_page.dart';
import '../../services/user_store.dart';
import '../../services/assessment_api.dart';
import '../assessment/assessment_results.dart';

// TODO: now the pet is assumed to be first pet, need to update to selected pet

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
  bool isLoadingAssessment = false;
  String? errorText;

  List<Map<String, dynamic>> pets = [];
  Map<String, dynamic>? latestAssessment;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    try {
      final access = await TokenStore.readAccess();
      if (access == null) throw "No access token found.";

      final petList = await PetsApi.listPets();

      if (petList.isNotEmpty) {
        final firstPetId = petList.first["id"] as int;
        await PetStore.setCurrentPetId(firstPetId);
      }

      if (!mounted) return;

      setState(() {
        pets = petList;
        isLoading = false;
      });

      if (petList.isNotEmpty) {
        final firstPetId = petList.first["id"] as int;
        await _loadLatestAssessment(firstPetId);
      }
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

    setState(() {
      isLoadingAssessment = true;
    });

    try {
      final assessment = await AssessmentApi.getLatestAssessment(petId: petId);

      if (!mounted) return;

      setState(() {
        latestAssessment = assessment;
        isLoadingAssessment = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        latestAssessment = null;
        isLoadingAssessment = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }

  Widget _content() {
    final pet = pets.isNotEmpty ? pets.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "My pets",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 14),
          pet == null ? _emptyPetCard() : _petCard(pet),
          const SizedBox(height: 14),
          _historyCard(pet),
          const SizedBox(height: 22),
          const Text(
            "More actions",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 5),
          _actionRow(Icons.add_circle_outline, "Add a new pet", onTap: () {}),
          _actionRow(Icons.group_outlined, "Add a family member", onTap: () {}),
          _actionRow(
            Icons.add_circle_outline,
            "Take a new test",
            onTap: _handleTakeNewTest,
          ),
        ],
      ),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade300,
            ),
            child: const Icon(Icons.pets, color: muted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  petName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 6),
                if (infoLines.isNotEmpty)
                  Text(
                    infoLines.join("\n"),
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                const SizedBox(height: 10),
                const Text(
                  "Favorite Foods",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
                const Text("—", style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 8),
                const Text(
                  "Favorite Activities",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
                const Text("—", style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 8),
                const Text(
                  "Medication history",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic>? pet) {
    final heartScore = latestAssessment?["heart_score"];
    final conditionScore = latestAssessment?["condition_score"];
    final assessedAtRaw = latestAssessment?["submitted_at"];
    final assessedAtText = _formatAssessmentDate(assessedAtRaw);
    final petName = (pet?["name"] ?? "").toString().trim();
    final hasAssessment = latestAssessment != null;

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
                    significantlyChallenged: _hasSignificantlyChallengedFlag(),
                    onDone: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              );
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

  Future<void> _handleTakeNewTest() async {
    if (pets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add a pet first.")),
      );
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
    final ownerName = await UserStore.getOwnerName();

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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Select a pet",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 16),
                ...pets.map((pet) {
                  final petName = (pet["name"] ?? "").toString().trim();
                  final breed = (pet["breed_text"] ?? "").toString().trim();
                  final species = (pet["species"] ?? "").toString().trim();

                  final subtitle = [
                    if (breed.isNotEmpty) breed,
                    if (species.isNotEmpty) species,
                  ].join(" • ");

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.pets, color: muted),
                    ),
                    title: Text(
                      petName.isEmpty ? "Unnamed pet" : petName,
                      style: const TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: subtitle.isEmpty
                        ? null
                        : Text(subtitle, style: const TextStyle(color: muted)),
                    trailing: const Icon(Icons.chevron_right, color: muted),
                    onTap: () => Navigator.of(context).pop(pet),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _hasSignificantlyChallengedFlag() {
    final value = latestAssessment?["significantly_challenged"];

    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == "true";
    if (value is int) return value == 1;

    return false;
  }
}