import 'dart:convert';
import 'package:frontend/services/token_store.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class AuthApi {
  static Uri _u(String path) => Uri.parse("${AppConfig.apiBaseUrl}$path");

  static Future<void> register({
    required String email,
    required String password,
    required String password2,
  }) async {
    final res = await http.post(
      _u("/api/accounts/register/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
        "password2": password2,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ?? "Register failed (${res.statusCode})";
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      _u("/api/accounts/token/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ?? "Login failed (${res.statusCode})";
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<String> refreshAccess({required String refreshToken}) async {
    final res = await http.post(
      _u("/api/accounts/token/refresh/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refresh": refreshToken}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ?? "Refresh failed (${res.statusCode})";
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final access = decoded["access"];
    if (access is! String || access.isEmpty) {
      throw "Refresh response missing access token";
    }
    return access;
  }

  Future<String?> refreshAccessToken() async {
    final refreshToken = await TokenStore.readRefresh();

    if (refreshToken == null) return null;

    final response = await http.post(
      _u("/api/auth/token/refresh/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refresh": refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final newAccess = data["access"];

      await TokenStore.saveAccessToken(newAccess);
      return newAccess;
    }

    return null; // refresh failed
  }

  static String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        if (decoded["detail"] is String) return decoded["detail"] as String;
        for (final v in decoded.values) {
          if (v is List && v.isNotEmpty) return v.first.toString();
          if (v is String) return v;
        }
      }
    } catch (_) {}
    return null;
  }
}
