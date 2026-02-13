import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../services/token_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? serverErrorText;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    setState(() => serverErrorText = null);

    if (email.isEmpty || password.isEmpty) {
      setState(() => serverErrorText = "Please enter email and password.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final tokens = await AuthApi.login(email: email, password: password);

      final access = tokens["access"];
      final refresh = tokens["refresh"];

      if (access is! String || refresh is! String) {
        throw "Login response missing access/refresh tokens.";
      }

      await TokenStore.save(access: access, refresh: refresh);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/profile');
    } catch (e) {
      setState(() => serverErrorText = e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 70),
              const Text(
                'Welcome to xxx',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD88442),
                ),
              ),
              const SizedBox(height: 70),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF676767)),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF676767)),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              if (serverErrorText != null) ...[
                Text(
                  serverErrorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 10),

              Center(
                child: SizedBox(
                  width: 130,
                  height: 36,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : _onLogin,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF676767)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Forgot password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF676767),
                ),
              ),

              const Spacer(),

              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text(
                  "Don't have an account? Register",
                  style: TextStyle(color: Color(0xFF676767)),
                ),
              ),

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}