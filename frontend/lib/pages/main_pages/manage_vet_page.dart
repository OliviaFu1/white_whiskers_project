import 'package:flutter/material.dart';
import '../../services/account_api.dart';

class ManageVetPage extends StatefulWidget {
  const ManageVetPage({super.key});

  @override
  State<ManageVetPage> createState() => _ManageVetPageState();
}

class _ManageVetPageState extends State<ManageVetPage> {
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);

  bool _loading = true;
  bool _savingPrimary = false;
  String? _errorText;

  final _clinicController = TextEditingController();
  final _primaryVetController = TextEditingController();
  final _primaryEmailController = TextEditingController();

  List<Map<String, dynamic>> _specialists = [];

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void dispose() {
    _clinicController.dispose();
    _primaryVetController.dispose();
    _primaryEmailController.dispose();
    super.dispose();
  }

  bool get _hasPrimaryClinicInfo {
    return _clinicController.text.trim().isNotEmpty ||
        _primaryVetController.text.trim().isNotEmpty ||
        _primaryEmailController.text.trim().isNotEmpty;
  }

  Future<void> _loadPage() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final me = await AccountApi.getMe();

      final specialistsRaw = me["specialists"];
      final specialists = specialistsRaw is List
          ? specialistsRaw.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      if (!mounted) return;

      setState(() {
        _clinicController.text = (me["primary_clinic"] ?? "").toString();
        _primaryVetController.text = (me["primary_vet_name"] ?? "").toString();
        _primaryEmailController.text = (me["primary_vet_email"] ?? "")
            .toString();
        _specialists = specialists;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _savePrimaryVet() async {
    setState(() => _savingPrimary = true);

    try {
      final updated = await AccountApi.updateMe(
        primaryClinic: _clinicController.text.trim(),
        primaryVetName: _primaryVetController.text.trim(),
        primaryVetEmail: _primaryEmailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _clinicController.text = (updated["primary_clinic"] ?? "").toString();
        _primaryVetController.text = (updated["primary_vet_name"] ?? "")
            .toString();
        _primaryEmailController.text = (updated["primary_vet_email"] ?? "")
            .toString();

        final specialistsRaw = updated["specialists"];
        _specialists = specialistsRaw is List
            ? specialistsRaw.cast<Map<String, dynamic>>()
            : _specialists;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Primary vet information updated.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not save: $e")));
    } finally {
      if (mounted) {
        setState(() => _savingPrimary = false);
      }
    }
  }

  Future<void> _showPrimaryVetEditor({bool autoOpened = false}) async {
    final clinicController = TextEditingController(
      text: _clinicController.text,
    );
    final vetController = TextEditingController(
      text: _primaryVetController.text,
    );
    final emailController = TextEditingController(
      text: _primaryEmailController.text,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: !autoOpened,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            _hasPrimaryClinicInfo ? "Edit primary vet" : "Add primary vet",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: Column(
                children: [
                  if (autoOpened) ...[
                    const Text(
                      "Add your primary clinic information so it’s easy to keep your pet’s care team in one place.",
                      style: TextStyle(
                        fontSize: 14,
                        color: muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _dialogField(controller: clinicController, hint: "Clinic"),
                  const SizedBox(height: 12),
                  _dialogField(controller: vetController, hint: "Vet name"),
                  const SizedBox(height: 12),
                  _dialogField(
                    controller: emailController,
                    hint: "Vet email",
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (!autoOpened)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel", style: TextStyle(color: muted)),
              ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: titleColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _savingPrimary
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    _clinicController.text = clinicController.text.trim();
    _primaryVetController.text = vetController.text.trim();
    _primaryEmailController.text = emailController.text.trim();

    await _savePrimaryVet();
  }

  Future<void> _showSpecialistEditor({Map<String, dynamic>? specialist}) async {
    final clinicController = TextEditingController(
      text: (specialist?["clinic_name"] ?? "").toString(),
    );
    final vetController = TextEditingController(
      text: (specialist?["vet_name"] ?? "").toString(),
    );
    final emailController = TextEditingController(
      text: (specialist?["vet_email"] ?? "").toString(),
    );
    final specialtyController = TextEditingController(
      text: (specialist?["specialty"] ?? "").toString(),
    );

    final isEditing = specialist != null;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            isEditing ? "Edit specialist" : "Add specialist",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: Column(
                children: [
                  _dialogField(
                    controller: clinicController,
                    hint: "Clinic name",
                  ),
                  const SizedBox(height: 12),
                  _dialogField(controller: vetController, hint: "Vet name"),
                  const SizedBox(height: 12),
                  _dialogField(
                    controller: emailController,
                    hint: "Vet email",
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _dialogField(
                    controller: specialtyController,
                    hint: "Specialty",
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel", style: TextStyle(color: muted)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: titleColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(isEditing ? "Save" : "Add"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final vetName = vetController.text.trim();
    if (vetName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Vet name is required.")));
      return;
    }

    try {
      if (isEditing) {
        await AccountApi.updateSpecialist(
          specialistId: specialist["id"] as int,
          clinicName: clinicController.text.trim(),
          vetName: vetName,
          vetEmail: emailController.text.trim(),
          specialty: specialtyController.text.trim(),
        );
      } else {
        await AccountApi.createSpecialist(
          clinicName: clinicController.text.trim(),
          vetName: vetName,
          vetEmail: emailController.text.trim(),
          specialty: specialtyController.text.trim(),
        );
      }

      if (!mounted) return;
      await _loadPage();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? "Specialist updated." : "Specialist added.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not save specialist: $e")));
    }
  }

  Future<void> _deleteSpecialist(Map<String, dynamic> specialist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            "Delete specialist",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          content: Text(
            'Remove ${(specialist["vet_name"] ?? "this specialist").toString()}?',
            style: const TextStyle(color: muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel", style: TextStyle(color: muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await AccountApi.deleteSpecialist(specialist["id"] as int);

      if (!mounted) return;
      await _loadPage();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Specialist removed.")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not delete specialist: $e")),
      );
    }
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF6EFE9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
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

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: muted, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPrimaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Primary care vet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "You haven’t added a primary clinic yet.",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Save your clinic, vet name, and email so they’re easy to find later.",
            style: TextStyle(fontSize: 14, color: muted, height: 1.35),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: titleColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _savingPrimary ? null : () => _showPrimaryVetEditor(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Add primary vet"),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryInfoCard() {
    final clinic = _clinicController.text.trim();
    final vetName = _primaryVetController.text.trim();
    final vetEmail = _primaryEmailController.text.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Primary care vet",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _savingPrimary
                    ? null
                    : () => _showPrimaryVetEditor(),
                icon: const Icon(Icons.edit_outlined, size: 18, color: accent),
                label: const Text(
                  "Edit",
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (clinic.isNotEmpty) _infoLine("Clinic", clinic),
          if (vetName.isNotEmpty) _infoLine("Vet", vetName),
          if (vetEmail.isNotEmpty) _infoLine("Email", vetEmail),
        ],
      ),
    );
  }

  Widget _buildPrimarySection() {
    return _hasPrimaryClinicInfo
        ? _buildPrimaryInfoCard()
        : _buildEmptyPrimaryCard();
  }

  Widget _buildSpecialistCard(Map<String, dynamic> specialist) {
    final clinic = (specialist["clinic_name"] ?? "").toString().trim();
    final name = (specialist["vet_name"] ?? "").toString().trim();
    final email = (specialist["vet_email"] ?? "").toString().trim();
    final specialty = (specialist["specialty"] ?? "").toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? "Unnamed specialist" : name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: muted,
                    height: 1.1,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showSpecialistEditor(specialist: specialist),
                icon: const Icon(Icons.edit_outlined, color: accent, size: 20),
                tooltip: "Edit",
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: () => _deleteSpecialist(specialist),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                tooltip: "Delete",
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          if (clinic.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(clinic, style: const TextStyle(fontSize: 14, color: muted)),
          ],
          if (specialty.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(specialty, style: const TextStyle(fontSize: 14, color: muted)),
          ],
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(fontSize: 14, color: muted)),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorText != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorText!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      children: [
        const Text(
          "Manage vet clinic",
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Keep your pet’s care team in one place.",
          style: TextStyle(fontSize: 15, color: muted),
        ),
        const SizedBox(height: 18),
        _buildPrimarySection(),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                "Specialists",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showSpecialistEditor(),
              icon: const Icon(Icons.add, color: accent, size: 18),
              label: const Text(
                "Add",
                style: TextStyle(color: accent, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_specialists.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: const Text(
              "No specialists added yet.",
              style: TextStyle(color: muted),
            ),
          )
        else
          ..._specialists.map(_buildSpecialistCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: muted,
        title: const Text(
          "Vet clinic",
          style: TextStyle(color: muted, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }
}
