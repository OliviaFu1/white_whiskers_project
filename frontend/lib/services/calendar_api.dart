import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class CalendarApi {
  static Uri _u(String path) => Uri.parse("${AppConfig.apiBaseUrl}$path");

  static Map<String, String> _authHeaders(String accessToken) => {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      };

  static Future<List<Map<String, dynamic>>> listDailyCheckins({
    required String accessToken,
    required int petId,
    String? date,
  }) async {
    final qp = <String, String>{"pet_id": petId.toString()};
    if (date != null) qp["date"] = date;

    final uri = _u("/api/calendar/daily-checkins/").replace(queryParameters: qp);

    final res = await http.get(uri, headers: _authHeaders(accessToken));

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
    required String accessToken,
    required int petId,
    String? date,
    String? tag,
    String? visibility, // shared|private
  }) async {
    final qp = <String, String>{"pet_id": petId.toString()};
    if (date != null) qp["date"] = date;
    if (tag != null) qp["tag"] = tag;
    if (visibility != null) qp["visibility"] = visibility;

    final uri = _u("/api/calendar/journal-entries/").replace(queryParameters: qp);

    final res = await http.get(uri, headers: _authHeaders(accessToken));

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
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    final res = await http.post(
      _u("/api/calendar/daily-checkins/"),
      headers: _authHeaders(accessToken),
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to create daily checkin (${res.statusCode})";
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createJournalEntry({
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    final res = await http.post(
      _u("/api/calendar/journal-entries/"),
      headers: _authHeaders(accessToken),
      body: jsonEncode(body),
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