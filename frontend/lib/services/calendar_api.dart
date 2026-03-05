import 'dart:convert';
import 'api_client.dart';

class CalendarApi {
  static Future<List<Map<String, dynamic>>> listDailyCheckins({
    required int petId,
    String? date,
  }) async {
    final qp = <String, String>{"pet_id": petId.toString()};
    if (date != null) qp["date"] = date;

    final res = await ApiClient.get(
      "/api/calendar/daily-checkins/",
      queryParameters: qp,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to load daily checkins (${res.statusCode})";
    }

    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    if (decoded is Map && decoded["results"] is List) {
      return (decoded["results"] as List).cast<Map<String, dynamic>>();
    }
    throw "Unexpected daily-checkins response format";
  }

  static Future<List<Map<String, dynamic>>> listJournalEntries({
    required int petId,
    String? date,
    String? tag,
    String? visibility, // shared|private
  }) async {
    final qp = <String, String>{"pet_id": petId.toString()};
    if (date != null) qp["date"] = date;
    if (tag != null) qp["tag"] = tag;
    if (visibility != null) qp["visibility"] = visibility;

    final res = await ApiClient.get(
      "/api/calendar/journal-entries/",
      queryParameters: qp,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to load journal entries (${res.statusCode})";
    }

    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    if (decoded is Map && decoded["results"] is List) {
      return (decoded["results"] as List).cast<Map<String, dynamic>>();
    }
    throw "Unexpected journal-entries response format";
  }

  static Future<Map<String, dynamic>> createDailyCheckin({
    required Map<String, dynamic> body,
  }) async {
    final res = await ApiClient.post(
      "/api/calendar/daily-checkins/",
      jsonBody: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to create daily checkin (${res.statusCode})";
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateDailyCheckin({
    required int id,
    required Map<String, dynamic> body,
  }) async {
    final res = await ApiClient.patch(
      "/api/calendar/daily-checkins/$id/",
      jsonBody: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to update daily checkin (${res.statusCode})";
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createJournalEntry({
    required Map<String, dynamic> body,
  }) async {
    final res = await ApiClient.post(
      "/api/calendar/journal-entries/",
      jsonBody: body,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to create journal entry (${res.statusCode})";
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