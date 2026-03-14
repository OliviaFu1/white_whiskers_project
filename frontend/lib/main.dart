import 'package:flutter/material.dart';
import 'package:frontend/pages/auth/auth_gate.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/main_pages/mypet_page.dart';
import 'pages/onboarding/onboarding_flow.dart';
import 'pages/auth/post_login_gate.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
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
      home: const AuthGate(),
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
