import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config.dart';
import '../services/api_client.dart';
import '../services/token_store.dart';

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

  static Future<Map<String, dynamic>> getPet(int petId) async {
    final res = await ApiClient.get("/api/pets/$petId/");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ?? "Failed to load pet (${res.statusCode})";
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updatePet({
    required int petId,
    required Map<String, dynamic> body,
  }) async {
    final res = await ApiClient.patch("/api/pets/$petId/", jsonBody: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to update pet (${res.statusCode})";
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

  static Future<void> deletePet(int petId) async {
    final res = await ApiClient.delete("/api/pets/$petId/");

    if (res.statusCode != 204) {
      throw _extractError(res.body) ??
          "Failed to delete pet (${res.statusCode})";
    }
  }

  static Future<Map<String, dynamic>> uploadPetPhoto(
    int petId,
    String filePath, {
    String mimeType = 'image/jpeg',
  }) async {
    final access = await TokenStore.readAccess();
    if (access == null) throw "No access token.";

    final uri = Uri.parse("${AppConfig.apiBaseUrl}/api/pets/$petId/photo/");
    final request = http.MultipartRequest('PATCH', uri)
      ..headers['Authorization'] = 'Bearer $access'
      ..files.add(
        await http.MultipartFile.fromPath(
          'photo',
          filePath,
          contentType: MediaType.parse(mimeType),
        ),
      );
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Photo upload failed (${res.statusCode})";
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
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
