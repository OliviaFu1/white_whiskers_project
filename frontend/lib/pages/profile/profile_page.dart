import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/pages/auth/auth_gate.dart';
import 'package:frontend/pages/profile/privacy_page.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/token_store.dart';
import 'package:frontend/state/auth_state.dart';
import 'package:frontend/state/notifiers.dart';
import 'package:frontend/widgets/user_avatar.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _EditProfileSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(onEdit: () => _openEdit(context)),
            const SizedBox(height: 24),
            const _SettingsSection(),
            const Spacer(),
            const Divider(),
            const SizedBox(height: 16),
            const _ProfileActions(),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final VoidCallback onEdit;

  const _ProfileHeader({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<User?>(
      valueListenable: userNotifier,
      builder: (context, user, _) {
        return _ProfileHeaderCard(user: user, onEdit: onEdit);
      },
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final User? user;
  final VoidCallback onEdit;

  const _ProfileHeaderCard({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: _ProfileInfo(user: user),
          ),
          _EditProfileButton(onEdit: onEdit),
        ],
      ),
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  final User? user;

  const _ProfileInfo({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(user: user, radius: 36),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileName(user: user),
              const SizedBox(height: 4),
              _ProfileLocation(user: user),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileName extends StatelessWidget {
  final User? user;

  const _ProfileName({required this.user});

  @override
  Widget build(BuildContext context) {
    final fullName = [
      user?.name ?? '',
      user?.lastName ?? '',
    ].where((s) => s.isNotEmpty).join(' ');

    return Text(
      fullName.isNotEmpty ? fullName : '—',
      style: Theme.of(context).textTheme.titleLarge,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ProfileLocation extends StatelessWidget {
  final User? user;

  const _ProfileLocation({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user?.location?.isNotEmpty != true) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        const Icon(Icons.location_on, size: 16),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            user!.location!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _EditProfileButton extends StatelessWidget {
  final VoidCallback onEdit;

  const _EditProfileButton({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6,
      right: 6,
      child: OutlinedButton.icon(
        label: const Text('Edit'),
        icon: const Icon(Icons.edit, size: 16),
        onPressed: onEdit,
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Settings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Card(
          color: Colors.white,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Privacy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyPage()),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help & Support'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileActions extends StatelessWidget {
  const _ProfileActions();

  Future<void> _logout(BuildContext context) async {
    await TokenStore.clear();
    AuthState.instance.logout();
    userNotifier.value = null;

    if (!context.mounted) return;

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => _logout(context),
      child: const Text('Logout'),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _location;
  late String _photoUrl;
  bool _uploadingPhoto = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = userNotifier.value;
    _firstName = TextEditingController(text: user?.name ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
    _location = TextEditingController(text: user?.location ?? '');
    _photoUrl = user?.photoUrl ?? '';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _removePhoto() async {
    setState(() => _uploadingPhoto = true);
    try {
      final res = await ApiClient.deletePhoto();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        userNotifier.value = User.fromJson(data);
        setState(() => _photoUrl = '');
      } else {
        setState(() => _error = 'Failed to remove photo (${res.statusCode})');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final res = await ApiClient.uploadPhoto(
        image.path,
        mimeType: image.mimeType ?? 'image/jpeg',
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        userNotifier.value = User.fromJson(data);
        setState(() => _photoUrl = data['photo_url'] as String? ?? '');
      } else {
        setState(() => _error = 'Photo upload failed (${res.statusCode})');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final res = await ApiClient.patch(
        '/api/accounts/me/',
        jsonBody: {
          'name': _firstName.text.trim(),
          'last_name': _lastName.text.trim(),
          'location': _location.text.trim(),
        },
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        userNotifier.value = User.fromJson(data);
        if (mounted) Navigator.pop(context);
      } else {
        setState(() => _error = 'Failed to save (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _EditAvatar(
            firstName: _firstName.text,
            lastName: _lastName.text,
            photoUrl: _photoUrl,
            uploading: _uploadingPhoto,
            onTap: _uploadingPhoto ? null : _pickPhoto,
          ),
          if (_photoUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _uploadingPhoto ? null : _removePhoto,
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
              label: const Text('Remove photo', style: TextStyle(color: Colors.red)),
            ),
          ],
          const SizedBox(height: 24),
          _NameFields(firstName: _firstName, lastName: _lastName),
          const SizedBox(height: 16),
          _LocationField(location: _location),
          const SizedBox(height: 24),
          _EditActions(
            saving: _saving,
            error: _error,
            onCancel: () => Navigator.pop(context),
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

class _EditAvatar extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String photoUrl;
  final bool uploading;
  final VoidCallback? onTap;

  const _EditAvatar({
    required this.firstName,
    required this.lastName,
    required this.photoUrl,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          UserAvatar(
            user: User(
              name: firstName,
              lastName: lastName.isEmpty ? null : lastName,
              photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
            ),
            radius: 44,
          ),
          if (uploading)
            const Positioned.fill(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: Colors.black45,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary,
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
}

class _NameFields extends StatelessWidget {
  final TextEditingController firstName;
  final TextEditingController lastName;

  const _NameFields({required this.firstName, required this.lastName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: firstName,
            decoration: const InputDecoration(
              labelText: 'First name',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: lastName,
            decoration: const InputDecoration(
              labelText: 'Last name',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationField extends StatefulWidget {
  final TextEditingController location;

  const _LocationField({required this.location});

  @override
  State<_LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<_LocationField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  final _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  String _pendingInput = '';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.location.text);
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _removeOverlay();
        });
      }
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay(List<String> suggestions) {
    _removeOverlay();
    if (suggestions.isEmpty) return;

    final renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: offset.dx,
        width: size.width,
        // anchor the bottom of the list to the top of the text field
        bottom: screenHeight - offset.dy,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: suggestions.length,
              itemBuilder: (_, index) {
                final option = suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place, size: 18),
                  title: Text(
                    option,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectOption(option),
                );
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _fetchSuggestions(String input) async {
    if (input.length < 2) {
      _removeOverlay();
      return;
    }
    _pendingInput = input;
    await Future.delayed(const Duration(milliseconds: 400));
    if (_pendingInput != input) return;

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': input,
      'format': 'json',
      'limit': '5',
    });
    try {
      final res = await http.get(
        uri,
        headers: {
          'Accept-Language': 'en',
          'User-Agent': 'WhiteWhiskersApp/1.0',
        },
      );
      if (res.statusCode == 200 && mounted && _pendingInput == input) {
        final results = jsonDecode(res.body) as List;
        _showOverlay(results.map((r) => r['display_name'] as String).toList());
      }
    } catch (_) {}
  }

  void _selectOption(String option) {
    _ctrl.text = option;
    widget.location.text = option;
    _removeOverlay();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: _fieldKey,
      controller: _ctrl,
      focusNode: _focus,
      onChanged: (v) {
        widget.location.text = v;
        _fetchSuggestions(v);
      },
      decoration: const InputDecoration(
        labelText: 'Location',
        prefixIcon: Icon(Icons.location_on),
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _EditActions extends StatelessWidget {
  final bool saving;
  final String? error;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _EditActions({
    required this.saving,
    required this.error,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          Text(error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
