import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../services/token_store.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    try {
      final access = await TokenStore.readAccess();
      if (access == null) throw "No access token found.";

      final petList = await AuthApi.listPets(accessToken: access);

      setState(() {
        pets = petList;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorText = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await TokenStore.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
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
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _circleIcon(Icons.person_outline, onTap: _logout), // temp logout
              _circleIcon(Icons.emoji_events_outlined, onTap: () {}),
            ],
          ),

          const SizedBox(height: 18),

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

          _historyCard(),

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
          _actionRow(Icons.add_circle_outline, "Take a new test", onTap: () {}),

          const Spacer(),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              _BottomIcon(Icons.calendar_month_outlined, selected: false),
              _BottomIcon(Icons.receipt_long_outlined, selected: false),
              _BottomIcon(Icons.pets_outlined, selected: true), // current page
            ],
          ),

          const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: muted),
        ),
        child: Icon(icon, color: muted),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(),
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

    // Build a simple 2–3 line info block without extra formatting
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

  Widget _historyCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: const [
          SizedBox(width: 4),
          Text("—", style: TextStyle(color: muted)),
          Spacer(),
          Text(
            "heart ",
            style: TextStyle(color: muted, fontWeight: FontWeight.w600),
          ),
          Text(
            "—",
            style: TextStyle(
              color: muted,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 18),
          Text(
            "condition ",
            style: TextStyle(color: muted, fontWeight: FontWeight.w600),
          ),
          Text(
            "—",
            style: TextStyle(
              color: muted,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 6),
          Icon(Icons.chevron_right, color: muted),
        ],
      ),
    );
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
}

class _BottomIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  const _BottomIcon(this.icon, {required this.selected});

  @override
  Widget build(BuildContext context) {
    const active = Color(0xFFD88442);
    const inactive = Color(0xFF676767);

    final border = selected ? active : inactive;
    final iconColor = selected ? active : inactive;

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: selected ? 2 : 1),
      ),
      child: Icon(icon, color: iconColor),
    );
  }
}
