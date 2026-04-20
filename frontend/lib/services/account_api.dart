import 'dart:convert';
import 'api_client.dart';

class AccountApi {
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

  static Future<Map<String, dynamic>> getMe() async {
    final res = await ApiClient.get("/api/accounts/me/");
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ?? "Failed to load profile.";
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateMe({
    String? name,
    String? lastName,
    String? location,
    String? primaryClinic,
    String? primaryVetName,
    String? primaryVetEmail,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body["name"] = name;
    if (lastName != null) body["last_name"] = lastName;
    if (location != null) body["location"] = location;
    if (primaryClinic != null) body["primary_clinic"] = primaryClinic;
    if (primaryVetName != null) body["primary_vet_name"] = primaryVetName;
    if (primaryVetEmail != null) body["primary_vet_email"] = primaryVetEmail;

    final res = await ApiClient.patch(
      "/api/accounts/me/",
      jsonBody: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to update profile (${res.statusCode})";
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> listSpecialists() async {
    final res = await ApiClient.get("/api/accounts/me/specialists/");
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ?? "Failed to load specialists.";
    }

    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    if (decoded is Map && decoded["results"] is List) {
      return (decoded["results"] as List).cast<Map<String, dynamic>>();
    }
    throw "Unexpected specialists response format";
  }

  static Future<Map<String, dynamic>> createSpecialist({
    required String vetName,
    String? clinicName,
    String? vetEmail,
    String? specialty,
  }) async {
    final res = await ApiClient.post(
      "/api/accounts/me/specialists/",
      jsonBody: {
        "vet_name": vetName,
        "clinic_name": clinicName ?? "",
        "vet_email": vetEmail ?? "",
        "specialty": specialty ?? "",
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ?? "Failed to add specialist.";
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateSpecialist({
    required int specialistId,
    String? vetName,
    String? clinicName,
    String? vetEmail,
    String? specialty,
  }) async {
    final body = <String, dynamic>{};
    if (vetName != null) body["vet_name"] = vetName;
    if (clinicName != null) body["clinic_name"] = clinicName;
    if (vetEmail != null) body["vet_email"] = vetEmail;
    if (specialty != null) body["specialty"] = specialty;

    final res = await ApiClient.patch(
      "/api/accounts/me/specialists/$specialistId/",
      jsonBody: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ?? "Failed to update specialist.";
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> deleteSpecialist(int specialistId) async {
    final res = await ApiClient.delete(
      "/api/accounts/me/specialists/$specialistId/",
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ?? "Failed to delete specialist.";
    }
  }
}