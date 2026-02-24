import 'dart:convert';
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

  static Future<Map<String, dynamic>> me({required String accessToken}) async {
    final res = await http.get(
      _u("/api/accounts/me/"),
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ?? "Failed to load profile.";
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateMe({
    required String accessToken,
    String? name,
    String? photoUrl,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body["name"] = name;
    if (photoUrl != null) body["photo_url"] = photoUrl;

    final res = await http.patch(
      _u("/api/accounts/me/"),
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to update profile (${res.statusCode})";
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createPet({
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    final res = await http.post(
      _u("/api/pets/"),
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to create pet (${res.statusCode})";
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> listPets({
    required String accessToken,
  }) async {
    final res = await http.get(
      _u("/api/pets/"),
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to load pets (${res.statusCode})";
    }

    final decoded = jsonDecode(res.body);

    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    if (decoded is Map && decoded["results"] is List) {
      return (decoded["results"] as List).cast<Map<String, dynamic>>();
    }
    throw "Unexpected pets response format";
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
