import 'package:flutter/material.dart';
import 'package:frontend/pages/app_shell.dart';
import 'package:frontend/state/notifiers.dart';
// import 'package:frontend/pages/app_shell.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/main_pages/mypet_page.dart';
import 'pages/onboarding/onboarding_flow.dart';
import 'pages/auth/post_login_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await loadPets();
  await loadNotifications();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFBF2EB),
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF917869),
          primary: const Color(0xFF917869),
        ),

        splashColor: const Color(0x33917869),
        highlightColor: Colors.transparent,
      ),
      home: AppShell(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/post-login': (_) => const PostLoginGate(),
        '/onboarding': (_) => const OnboardingFlow(),
        '/mypets': (_) => const MypetPage(),
      },
    );
  }
}
