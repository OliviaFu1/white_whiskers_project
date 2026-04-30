import 'dart:convert';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'api_client.dart';

class MedicationApi {
  static Future<List<Map<String, dynamic>>> listMedications({
    required int petId,
  }) async {
    final res = await ApiClient.get(
      "/api/medications/",
      queryParameters: {"pet_id": petId.toString()},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to load medications (${res.statusCode})";
    }

    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    if (decoded is Map && decoded["results"] is List) {
      return (decoded["results"] as List).cast<Map<String, dynamic>>();
    }
    throw "Unexpected medications response format";
  }

  static Future<Map<String, dynamic>> createMedication({
    required Map<String, dynamic> body,
  }) async {
    final res = await ApiClient.post("/api/medications/", jsonBody: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to create medication (${res.statusCode})";
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateMedication({
    required int id,
    required Map<String, dynamic> body,
  }) async {
    final res =
        await ApiClient.patch("/api/medications/$id/", jsonBody: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to update medication (${res.statusCode})";
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> deleteMedication(int id) async {
    final res = await ApiClient.delete("/api/medications/$id/");

    if (res.statusCode != 204) {
      throw _extractError(res.body) ??
          "Failed to delete medication (${res.statusCode})";
    }
  }

  // ── Prescriptions ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> listPrescriptions({
    required int medicationId,
  }) async {
    final res = await ApiClient.get(
      "/api/medications/$medicationId/prescriptions/",
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to load prescriptions (${res.statusCode})";
    }
    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    if (decoded is Map && decoded["results"] is List) {
      return (decoded["results"] as List).cast<Map<String, dynamic>>();
    }
    throw "Unexpected prescriptions response format";
  }

  static Future<Map<String, dynamic>> createPrescription({
    required int medicationId,
    required Map<String, dynamic> body,
  }) async {
    final res = await ApiClient.post(
      "/api/medications/$medicationId/prescriptions/",
      jsonBody: body,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to create prescription (${res.statusCode})";
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updatePrescription({
    required int prescriptionId,
    required Map<String, dynamic> body,
  }) async {
    final res = await ApiClient.patch(
      "/api/medications/prescriptions/$prescriptionId/",
      jsonBody: body,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to update prescription (${res.statusCode})";
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> listLogs({
    required int medicationId,
  }) async {
    final res = await ApiClient.get("/api/medications/$medicationId/logs/");
    if (res.statusCode != 200) throw "Failed to load history";
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> updateLog({
    required int logId,
    required String notes,
  }) async {
    final res = await ApiClient.patch(
      "/api/medications/logs/$logId/",
      jsonBody: {"notes": notes},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ?? "Failed to update log entry (${res.statusCode})";
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> deleteLog(int logId) async {
    final res = await ApiClient.delete("/api/medications/logs/$logId/");
    if (res.statusCode != 204) {
      throw _extractError(res.body) ?? "Failed to delete log entry (${res.statusCode})";
    }
  }

  static Future<void> processDueDoses({
    required int petId,
    DateTime? ignoreBefore,
  }) async {
    String timezone = 'UTC';
    try {
      timezone = await FlutterTimezone.getLocalTimezone();
    } catch (_) {}
    final body = <String, dynamic>{"pet_id": petId, "timezone": timezone};
    if (ignoreBefore != null) {
      body["ignore_before"] = ignoreBefore.toUtc().toIso8601String();
    }
    final res = await ApiClient.post(
      "/api/medications/process-due-doses/",
      jsonBody: body,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to process due doses (${res.statusCode})";
    }
  }

  static Future<void> checkBirthdays() async {
    await ApiClient.post("/api/notifications/check-birthdays/", jsonBody: {});
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
