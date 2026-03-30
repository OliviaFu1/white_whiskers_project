import 'dart:convert';
import 'package:frontend/config.dart';

import 'api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:frontend/services/token_store.dart';

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
    String? visibility,
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

  static Future<String> uploadJournalPhoto(
    String imagePath, {
    String mimeType = 'image/jpeg',
  }) async {
    final access = await TokenStore.readAccess();
    if (access == null) {
      throw "No access token found.";
    }

    final uri = Uri.parse(
      "${AppConfig.apiBaseUrl}/api/calendar/journal-upload-photo/",
    );

    final request = http.MultipartRequest("POST", uri);
    request.headers["Authorization"] = "Bearer $access";

    final mimeParts = mimeType.split("/");
    final mediaType = mimeParts.length == 2
        ? MediaType(mimeParts[0], mimeParts[1])
        : MediaType("image", "jpeg");

    request.files.add(
      await http.MultipartFile.fromPath(
        "photo",
        imagePath,
        contentType: mediaType,
      ),
    );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to upload journal photo (${res.statusCode})";
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw "Unexpected upload-photo response format";
    }

    final photoUrl = decoded["photo_url"]?.toString() ?? "";
    if (photoUrl.isEmpty) {
      throw "photo_url missing in upload response";
    }

    return photoUrl;
  }

  static Future<List<Map<String, dynamic>>> listJournalTags() async {
    final res = await ApiClient.get("/api/calendar/journal-tags/");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to load journal tags (${res.statusCode})";
    }

    final decoded = jsonDecode(res.body);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    if (decoded is Map && decoded["results"] is List) {
      return (decoded["results"] as List).cast<Map<String, dynamic>>();
    }
    throw "Unexpected journal-tags response format";
  }

  static Future<Map<String, dynamic>> createJournalTag({
    required String name,
    required String color,
  }) async {
    final res = await ApiClient.post(
      "/api/calendar/journal-tags/",
      jsonBody: {"name": name.trim(), "color": color},
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to create journal tag (${res.statusCode})";
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> deleteJournalTag(int id) async {
    final res = await ApiClient.delete("/api/calendar/journal-tags/$id/");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw _extractError(res.body) ??
          "Failed to delete journal tag (${res.statusCode})";
    }
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