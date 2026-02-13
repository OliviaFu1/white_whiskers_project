import 'package:flutter/material.dart';
import '../services/auth_api.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool isLoading = false;
  bool isFormValid = false;
  String? serverErrorText;

  bool _emailTouched = false;
  bool _pwTouched = false;
  bool _confirmTouched = false;

  bool get _canSubmit {
    final email = emailController.text.trim();
    final p1 = passwordController.text;
    final p2 = confirmController.text;

    return _isValidEmail(email) && p1.length >= 8 && p1 == p2;
  }

  bool _isValidEmail(String email) {
    final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return re.hasMatch(email);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() {
      serverErrorText = null;
      isLoading = true;
    });

    final email = emailController.text.trim();
    final p1 = passwordController.text;
    final p2 = confirmController.text;

    try {
      await AuthApi.register(email: email, password: p1, password2: p2);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registered! Please log in.")),
      );

      Navigator.pushReplacementNamed(context, '/login');
      // add verification:
      // Navigator.pushReplacementNamed(context, '/verify', arguments: email);
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
                'Welcome to xxx!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD88442),
                ),
              ),
              const SizedBox(height: 70),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: _emailTouched
                          ? AutovalidateMode.always
                          : AutovalidateMode.disabled,
                      onChanged: (_) {
                        if (!_emailTouched) setState(() => _emailTouched = true);
                        setState(() {}); // updates button enable state
                      },
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF676767)),
                        ),
                      ),
                      validator: (value) {
                        final v = (value ?? "").trim();
                        if (v.isEmpty) return "Email is required.";
                        if (!_isValidEmail(v)) return "Please enter a valid email address.";
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      autovalidateMode:
                          _pwTouched ? AutovalidateMode.always : AutovalidateMode.disabled,
                      onChanged: (_) {
                        if (!_pwTouched) setState(() => _pwTouched = true);
                        setState(() {});
                      },
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF676767)),
                        ),
                      ),
                      validator: (value) {
                        final v = value ?? "";
                        if (v.isEmpty) return "Password is required.";
                        if (v.length < 8) return "Ensure this field has at least 8 characters.";
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    TextFormField(
                      controller: confirmController,
                      obscureText: true,
                      autovalidateMode: _confirmTouched
                          ? AutovalidateMode.always
                          : AutovalidateMode.disabled,
                      onChanged: (_) {
                        if (!_confirmTouched) setState(() => _confirmTouched = true);
                        setState(() {});
                      },
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF676767)),
                        ),
                      ),
                      validator: (value) {
                        final v = value ?? "";
                        if (v.isEmpty) return "Please confirm your password.";
                        if (v != passwordController.text) return "Passwords do not match.";
                        return null;
                      },
                    ),
                  ],
                ),
              ),
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
                    onPressed: (!isLoading && _canSubmit) ? _onRegister : null,
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
                        : const Text('Register'),
                  ),
                ),
              ),

              const Spacer(),

              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text(
                  "Already have an account?",
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