import 'dart:convert';
import 'api_client.dart';

class AssessmentApi {
  static Future<List<Map<String, dynamic>>> listAssessments({
    int? petId,
  }) async {
    final qp = <String, String>{};
    if (petId != null) qp["pet_id"] = petId.toString();

    final res = await ApiClient.get(
      "/api/assessments/",
      queryParameters: qp.isEmpty ? null : qp,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to load assessments (${res.statusCode})";
    }

    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    if (decoded is Map && decoded["results"] is List) {
      return (decoded["results"] as List).cast<Map<String, dynamic>>();
    }
    throw "Unexpected assessments response format";
  }

  static Future<Map<String, dynamic>?> getLatestAssessment({
    required int petId,
  }) async {
    final assessments = await listAssessments(petId: petId);
    if (assessments.isEmpty) return null;

    assessments.sort((a, b) {
      final aTime = DateTime.tryParse((a["submitted_at"] ?? "").toString());
      final bTime = DateTime.tryParse((b["submitted_at"] ?? "").toString());

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return assessments.first;
  }

  static Future<Map<String, dynamic>> createAssessment({
    required Map<String, dynamic> body,
  }) async {
    final res = await ApiClient.post("/api/assessments/", jsonBody: body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to create assessment (${res.statusCode})";
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getAssessment({required int id}) async {
    final res = await ApiClient.get("/api/assessments/$id/");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to load assessment (${res.statusCode})";
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> deleteAssessment({required int id}) async {
    final res = await ApiClient.delete("/api/assessments/$id/");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to delete assessment (${res.statusCode})";
    }
  }

  static Future<List<Map<String, dynamic>>> listShareRecipients() async {
    final res = await ApiClient.get("/api/accounts/share-recipients/");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to load share recipients (${res.statusCode})";
    }

    final decoded = jsonDecode(res.body);
    if (decoded is List) {
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (decoded is Map && decoded["results"] is List) {
      return (decoded["results"] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    throw "Unexpected share recipients response format";
  }

  static Future<void> shareAssessment({
    required int assessmentId,
    required Map<String, dynamic> body,
  }) async {
    final res = await ApiClient.post(
      "/api/assessments/$assessmentId/share/",
      jsonBody: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to share assessment (${res.statusCode})";
    }
  }

  static String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        if (decoded["detail"] is String) return decoded["detail"] as String;
        for (final v in decoded.values) {
          if (v is List && v.isNotEmpty) return v.first.toString();
          if (v is String) return v.toString();
        }
      }
    } catch (_) {}
    return null;
  }
}
