import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'token_store.dart';
import 'auth_api.dart';

class ApiClient {
  static Uri _u(String path) => Uri.parse("${AppConfig.apiBaseUrl}$path");

  static Map<String, String> _headers(String accessToken) => {
    "Authorization": "Bearer $accessToken",
    "Content-Type": "application/json",
  };

  /// GET with automatic refresh+retry on 401
  static Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final access = await TokenStore.readAccess();
    if (access == null) throw "No access token found.";

    final uri = _u(path).replace(queryParameters: queryParameters);
    final res = await http.get(uri, headers: _headers(access));

    if (res.statusCode != 401) return res;

    // try refresh once
    final refreshed = await _refreshAccessOrThrow();
    final res2 = await http.get(uri, headers: _headers(refreshed));
    return res2;
  }

  /// POST with automatic refresh+retry on 401
  static Future<http.Response> post(
    String path, {
    Map<String, String>? queryParameters,
    Object? jsonBody,
  }) async {
    final access = await TokenStore.readAccess();
    if (access == null) throw "No access token found.";

    final uri = _u(path).replace(queryParameters: queryParameters);
    final res = await http.post(
      uri,
      headers: _headers(access),
      body: jsonBody == null ? null : jsonEncode(jsonBody),
    );

    if (res.statusCode != 401) return res;

    final refreshed = await _refreshAccessOrThrow();
    final res2 = await http.post(
      uri,
      headers: _headers(refreshed),
      body: jsonBody == null ? null : jsonEncode(jsonBody),
    );
    return res2;
  }

  /// PATCH with automatic refresh+retry on 401
  static Future<http.Response> patch(
    String path, {
    Map<String, String>? queryParameters,
    Object? jsonBody,
  }) async {
    final access = await TokenStore.readAccess();
    if (access == null) throw "No access token found.";

    final uri = _u(path).replace(queryParameters: queryParameters);
    final res = await http.patch(
      uri,
      headers: _headers(access),
      body: jsonBody == null ? null : jsonEncode(jsonBody),
    );

    if (res.statusCode != 401) return res;

    final refreshed = await _refreshAccessOrThrow();
    final res2 = await http.patch(
      uri,
      headers: _headers(refreshed),
      body: jsonBody == null ? null : jsonEncode(jsonBody),
    );
    return res2;
  }

  static Future<String> _refreshAccessOrThrow() async {
    final refresh = await TokenStore.readRefresh();
    if (refresh == null) {
      await TokenStore.clear();
      throw "Session expired. Please log in again.";
    }

    try {
      final newAccess = await AuthApi.refreshAccess(refreshToken: refresh);
      await TokenStore.save(access: newAccess, refresh: refresh);
      return newAccess;
    } catch (e) {
      await TokenStore.clear();
      throw "Session expired. Please log in again.";
    }
  }
}