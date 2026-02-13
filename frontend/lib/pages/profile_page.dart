import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../services/token_store.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;
  String? errorText;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final access = await TokenStore.readAccess();

      if (access == null) {
        throw "No access token found.";
      }

      final data = await AuthApi.me(accessToken: access);

      setState(() {
        userData = data;
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
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: const Color(0xFF917869),
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : errorText != null
                ? Text(
                    errorText!,
                    style: const TextStyle(color: Colors.red),
                  )
                : userData == null
                    ? const Text("No user data.")
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            userData!["email"] ?? "",
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            userData!["name"] ?? "",
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _logout,
                            child: const Text("Logout"),
                          ),
                        ],
                      ),
      ),
    );
  }
}