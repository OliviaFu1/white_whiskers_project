import 'package:flutter/material.dart';
import 'package:frontend/services/pets_api.dart';
import 'package:frontend/state/notifiers.dart';

class ManageFamilyMembersPage extends StatefulWidget {
  const ManageFamilyMembersPage({super.key});

  @override
  State<ManageFamilyMembersPage> createState() =>
      _ManageFamilyMembersPageState();
}

class _ManageFamilyMembersPageState extends State<ManageFamilyMembersPage> {
  static const bg = Color(0xFFFBF2EB);
  static const accent = Color(0xFF917869);
  static const titleColor = Color(0xFFD88442);
  static const muted = Color(0xFF676767);

  bool _loadingPets = true;
  bool _loadingData = false;
  String? _error;

  List<Map<String, dynamic>> _pets = [];
  int? _selectedPetId;

  Map<String, dynamic>? _familyData;
  final Set<int> _updatingUserIds = {};
  final Set<int> _cancelingInviteIds = {};

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  bool get _isOwner {
    return (_familyData?["current_user_role"] ?? "").toString() == "owner";
  }

  List<Map<String, dynamic>> get _members {
    final raw = _familyData?["members"];
    if (raw is List) {
      final members = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      members.sort((a, b) {
        final aIsMe = (a["is_me"] ?? false) == true;
        final bIsMe = (b["is_me"] ?? false) == true;
        if (aIsMe == bIsMe) return 0;
        return aIsMe ? -1 : 1;
      });
      return members;
    }
    return const [];
  }

  List<Map<String, dynamic>> get _invites {
    final raw = _familyData?["invites"];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  List<Map<String, dynamic>> get _rows {
    final rows = <Map<String, dynamic>>[];

    for (final member in _members) {
      final row = Map<String, dynamic>.from(member);
      row["_kind"] = "member";
      rows.add(row);
    }

    for (final invite in _invites) {
      final row = Map<String, dynamic>.from(invite);
      row["_kind"] = "invite";
      rows.add(row);
    }

    return rows;
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingPets = true;
      _error = null;
    });

    try {
      final pets = await PetsApi.listPets();

      int? selectedId = selectedPetNotifier.value?.id;
      if (selectedId == null && pets.isNotEmpty) {
        selectedId = pets.first["id"] as int?;
      }

      if (!mounted) return;

      setState(() {
        _pets = pets;
        _selectedPetId = selectedId;
        _loadingPets = false;
      });

      if (_selectedPetId != null) {
        await _loadFamilyData();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPets = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadFamilyData() async {
    final petId = _selectedPetId;
    if (petId == null) return;

    setState(() {
      _loadingData = true;
      _error = null;
    });

    try {
      final data = await PetsApi.getFamilyManagement(petId: petId);

      if (!mounted) return;
      setState(() {
        _familyData = data;
        _loadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingData = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _changeRole({
    required int userId,
    required String currentRole,
  }) async {
    if (!_isOwner || _selectedPetId == null) return;

    final nextRole = currentRole == "owner" ? "family" : "owner";

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Change role"),
          content: Text(
            nextRole == "owner"
                ? "Make this member an owner?"
                : "Change this owner to family member?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _updatingUserIds.add(userId);
    });

    try {
      await PetsApi.updateFamilyMemberRole(
        petId: _selectedPetId!,
        userId: userId,
        role: nextRole,
      );

      if (!mounted) return;
      await _loadFamilyData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextRole == "owner"
                ? "Changed to owner."
                : "Changed to family member.",
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not update role: $e")));
    } finally {
      if (!mounted) return;
      setState(() {
        _updatingUserIds.remove(userId);
      });
    }
  }

  Future<void> _cancelInvite(int inviteId) async {
    if (!_isOwner) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Cancel invite"),
          content: const Text("Cancel this pending invitation?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Keep"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Cancel invite"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _cancelingInviteIds.add(inviteId);
    });

    try {
      await PetsApi.cancelInvite(inviteId);

      if (!mounted) return;
      await _loadFamilyData();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invite canceled.")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not cancel invite: $e")));
    } finally {
      if (!mounted) return;
      setState(() {
        _cancelingInviteIds.remove(inviteId);
      });
    }
  }

  String _petName(Map<String, dynamic> pet) {
    final name = (pet["name"] ?? "").toString().trim();
    return name.isEmpty ? "Unnamed pet" : name;
  }

  String _roleLabel(String role) {
    return role == "owner" ? "Owner" : "Family member";
  }

  String _statusLabel(String status) {
    return status == "pending" ? "Pending" : "Connected";
  }

  String _displayName(Map<String, dynamic> item) {
    final name = (item["name"] ?? "").toString().trim();
    if (name.isNotEmpty) return name;

    final email = (item["email"] ?? item["invitee_email"] ?? "")
        .toString()
        .trim();
    if (email.isNotEmpty) return email.split("@").first;

    return "Unknown user";
  }

  String _emailText(Map<String, dynamic> item) {
    final email = (item["email"] ?? item["invitee_email"] ?? "")
        .toString()
        .trim();
    return email.isEmpty ? "No email" : email;
  }

  bool _isMe(Map<String, dynamic> item) {
    return (item["is_me"] ?? false) == true;
  }

  Widget _buildPetPicker() {
    if (_pets.isEmpty) {
      return _card(
        child: const Text(
          "No linked pets found.",
          style: TextStyle(color: muted),
        ),
      );
    }

    return _card(
      child: DropdownButtonFormField<int>(
        value: _selectedPetId,
        decoration: InputDecoration(
          labelText: "Pet",
          labelStyle: const TextStyle(color: muted),
          filled: true,
          fillColor: const Color(0xFFF8F2ED),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        items: _pets.map((pet) {
          final petId = pet["id"] as int;
          return DropdownMenuItem<int>(
            value: petId,
            child: Text(_petName(pet)),
          );
        }).toList(),
        onChanged: (value) async {
          if (value == null) return;
          setState(() {
            _selectedPetId = value;
            _familyData = null;
          });
          await _loadFamilyData();
        },
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 4), trailing],
      ],
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EAE3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> item) {
    final kind = (item["_kind"] ?? "").toString();
    final isInvite = kind == "invite";
    final isMe = _isMe(item);

    final name = _displayName(item);
    final email = _emailText(item);
    final role = (item["role"] ?? "family").toString();
    final status = (item["status"] ?? (isInvite ? "pending" : "connected"))
        .toString();

    final userId = item["user_id"] as int?;
    final inviteId = item["id"] as int?;

    final isUpdating = userId != null && _updatingUserIds.contains(userId);
    final isCanceling =
        inviteId != null && _cancelingInviteIds.contains(inviteId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCFA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E3DA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
              if (isMe) _buildBadge("Me"),
            ],
          ),
          const SizedBox(height: 4),
          Text(email, style: const TextStyle(fontSize: 13, color: muted)),
          const SizedBox(height: 8),
          _buildInfoRow(
            label: "Role",
            value: _roleLabel(role),
            trailing: _isOwner && !isInvite && !isMe && userId != null
                ? InkWell(
                    onTap: isUpdating
                        ? null
                        : () => _changeRole(userId: userId, currentRole: role),
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Center(
                        child: isUpdating
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: accent,
                              ),
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          if (!isMe) ...[
            _buildInfoRow(
              label: "Status",
              value: _statusLabel(status),
              trailing: _isOwner && isInvite && inviteId != null
                  ? InkWell(
                      onTap: isCanceling ? null : () => _cancelInvite(inviteId),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 56,
                        height: 22,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: isCanceling
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E3DA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: muted,
        title: const Text("Manage family members"),
      ),
      body: _loadingPets
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFamilyData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  _buildPetPicker(),
                  const SizedBox(height: 16),
                  if (_selectedPetId == null)
                    _card(
                      child: const Text(
                        "Please select a pet.",
                        style: TextStyle(color: muted),
                      ),
                    )
                  else if (_loadingData)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_familyData == null)
                    _card(
                      child: const Text(
                        "Could not load family member data.",
                        style: TextStyle(color: muted),
                      ),
                    )
                  else if (rows.isEmpty)
                    _card(
                      child: const Text(
                        "No family members or pending invites.",
                        style: TextStyle(color: muted),
                      ),
                    )
                  else
                    ...rows.map(_buildMemberCard),
                ],
              ),
            ),
    );
  }
}
