import 'dart:convert';
import '../services/api_client.dart';

class PetsApi {
  static Future<Map<String, dynamic>> createPet({
    required Map<String, dynamic> body,
  }) async {
    final res = await ApiClient.post("/api/pets/", jsonBody: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to create pet (${res.statusCode})";
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> listPets() async {
    final res = await ApiClient.get("/api/pets/");

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