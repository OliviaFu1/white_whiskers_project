import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/mypet_page.dart';
import 'pages/onboarding_flow.dart';
import 'pages/post_login_gate.dart';

void main() => runApp(const MyApp());

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
      home: const LoginPage(),
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