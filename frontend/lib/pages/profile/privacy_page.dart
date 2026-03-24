import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/main.dart';
import 'package:frontend/pages/auth/auth_gate.dart';
import 'package:frontend/services/api_client.dart';
import 'package:frontend/services/token_store.dart';
import 'package:frontend/state/auth_state.dart';
import 'package:frontend/state/notifiers.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _deleting = false;

  Future<void> _handleDeleteAccount() async {
    final confirmed = await _showDeleteAccountDialog(context);
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      final res = await ApiClient.delete('/api/accounts/me/');
      if (res.statusCode != 204) {
        throw 'Failed to delete account (${res.statusCode})';
      }

      await TokenStore.clear();
      AuthState.instance.logout();
      userNotifier.value = null;

      if (!mounted) return;

      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _deleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<bool?> _showDeleteAccountDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => const _DeleteAccountDialog(),
    );
  }

  Future<void> _handleChangeEmail() async {
    final currentEmail = userNotifier.value?.email ?? '';
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChangeEmailSheet(currentEmail: currentEmail),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email updated successfully.')),
      );
    }
  }

  Future<void> _handleChangePassword() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(label: 'Account'),
            _AccountSection(
              onChangeEmail: _handleChangeEmail,
              onChangePassword: _handleChangePassword,
            ),
            const SizedBox(height: 24),
            _DangerSection(
              deleting: _deleting,
              onDeleteAccount: _handleDeleteAccount,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _AccountSection extends StatelessWidget {
  final VoidCallback onChangeEmail;
  final VoidCallback onChangePassword;

  const _AccountSection({
    required this.onChangeEmail,
    required this.onChangePassword,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.email_outlined,
            title: 'Change Email',
            onTap: onChangeEmail,
          ),
          const Divider(height: 1),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: onChangePassword,
          ),
        ],
      ),
    );
  }
}

class _DangerSection extends StatelessWidget {
  final bool deleting;
  final VoidCallback onDeleteAccount;

  const _DangerSection({required this.deleting, required this.onDeleteAccount});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: _DeleteAccountTile(deleting: deleting, onTap: onDeleteAccount),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _DeleteAccountTile extends StatelessWidget {
  final bool deleting;
  final VoidCallback onTap;

  const _DeleteAccountTile({required this.deleting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: deleting
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.red,
              ),
            )
          : const Icon(Icons.delete_outline, color: Colors.red),
      title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
      onTap: deleting ? null : onTap,
    );
  }
}

String? _extractError(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      for (final v in decoded.values) {
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String) return v;
      }
    }
  } catch (_) {}
  return null;
}

class _ChangeEmailSheet extends StatefulWidget {
  final String currentEmail;
  const _ChangeEmailSheet({required this.currentEmail});

  @override
  State<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<_ChangeEmailSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _touched = false;
  bool _loading = false;
  String? _serverError;

  static bool _isValidEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);

  bool get _canSubmit => _isValidEmail(_emailCtrl.text.trim());

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _serverError = null;
    });
    try {
      final res = await ApiClient.patch(
        '/api/accounts/me/email/',
        jsonBody: {'new_email': _emailCtrl.text.trim()},
      );
      if (res.statusCode == 200) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(
          () => _serverError =
              _extractError(res.body) ?? 'Failed to update email.',
        );
      }
    } catch (e) {
      setState(() => _serverError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Change Email',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            if (widget.currentEmail.isNotEmpty) ...[
              const SizedBox(height: 20),
              TextField(
                controller: TextEditingController(text: widget.currentEmail),
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Current email',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFCCCCCC)),
                  ),
                  labelStyle: TextStyle(color: Color(0xFFAAAAAA)),
                ),
                style: const TextStyle(color: Color(0xFFAAAAAA)),
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autovalidateMode: _touched
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              onChanged: (_) {
                if (!_touched) setState(() => _touched = true);
                setState(() {});
              },
              decoration: const InputDecoration(
                labelText: 'New email',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF676767)),
                ),
              ),
              validator: (v) {
                final val = (v ?? '').trim();
                if (val.isEmpty) return 'Email is required.';
                if (!_isValidEmail(val)) return 'Enter a valid email address.';
                return null;
              },
            ),
            if (_serverError != null) ...[
              const SizedBox(height: 8),
              Text(
                _serverError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (!_loading && _canSubmit) ? _submit : null,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Email'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _currentTouched = false;
  bool _newTouched = false;
  bool _confirmTouched = false;
  bool _loading = false;
  String? _serverError;

  bool get _canSubmit =>
      _currentCtrl.text.isNotEmpty &&
      _newCtrl.text.length >= 8 &&
      _newCtrl.text == _confirmCtrl.text;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _serverError = null;
    });
    try {
      final res = await ApiClient.patch(
        '/api/accounts/me/password/',
        jsonBody: {
          'current_password': _currentCtrl.text,
          'new_password': _newCtrl.text,
          'confirm_password': _confirmCtrl.text,
        },
      );
      if (res.statusCode == 200) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(
          () => _serverError =
              _extractError(res.body) ?? 'Failed to update password.',
        );
      }
    } catch (e) {
      setState(() => _serverError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Change Password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _currentCtrl,
              obscureText: true,
              autovalidateMode: _currentTouched
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              onChanged: (_) {
                if (!_currentTouched) setState(() => _currentTouched = true);
                setState(() {});
              },
              decoration: const InputDecoration(
                labelText: 'Current password',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF676767)),
                ),
              ),
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Current password is required.' : null,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _newCtrl,
              obscureText: true,
              autovalidateMode: _newTouched
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              onChanged: (_) {
                if (!_newTouched) setState(() => _newTouched = true);
                setState(() {});
              },
              decoration: const InputDecoration(
                labelText: 'New password',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF676767)),
                ),
              ),
              validator: (v) {
                final val = v ?? '';
                if (val.isEmpty) return 'New password is required.';
                if (val.length < 8)
                  return 'Password must be at least 8 characters.';
                return null;
              },
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: true,
              autovalidateMode: _confirmTouched
                  ? AutovalidateMode.always
                  : AutovalidateMode.disabled,
              onChanged: (_) {
                if (!_confirmTouched) setState(() => _confirmTouched = true);
                setState(() {});
              },
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF676767)),
                ),
              ),
              validator: (v) {
                final val = v ?? '';
                if (val.isEmpty) return 'Please confirm your password.';
                if (val != _newCtrl.text) return 'Passwords do not match.';
                return null;
              },
            ),
            if (_serverError != null) ...[
              const SizedBox(height: 8),
              Text(
                _serverError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (!_loading && _canSubmit) ? _submit : null,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatelessWidget {
  const _DeleteAccountDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete account'),
      content: const Text(
        'Are you sure you want to permanently delete your account? '
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
