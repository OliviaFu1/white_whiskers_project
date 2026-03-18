import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/main.dart';
import 'package:frontend/pages/auth/auth_gate.dart';
import 'package:frontend/state/auth_state.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config.dart';
import 'token_store.dart';
import 'auth_api.dart';

class ApiClient {
  static Uri _u(String path) => Uri.parse("${AppConfig.apiBaseUrl}$path");

  static Map<String, String> _headers(String accessToken) => {
    "Authorization": "Bearer $accessToken",
    "Content-Type": "application/json",
  };

  static Future<String>? _refreshFuture;

  /// GET with refresh+retry
  static Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final access = await TokenStore.readAccess();
    if (access == null) throw "No access token.";

    final uri = _u(path).replace(queryParameters: queryParameters);
    final res = await http.get(uri, headers: _headers(access));

    if (res.statusCode != 401) return res;

    final newAccess = await _refreshAccessLocked();
    final res2 = await http.get(uri, headers: _headers(newAccess));
    return res2;
  }

  /// POST with refresh+retry
  static Future<http.Response> post(
    String path, {
    Map<String, String>? queryParameters,
    Object? jsonBody,
  }) async {
    final access = await TokenStore.readAccess();
    if (access == null) throw "No access token.";

    final uri = _u(path).replace(queryParameters: queryParameters);

    final res = await http.post(
      uri,
      headers: _headers(access),
      body: jsonBody == null ? null : jsonEncode(jsonBody),
    );

    if (res.statusCode != 401) return res;

    final newAccess = await _refreshAccessLocked();

    return await http.post(
      uri,
      headers: _headers(newAccess),
      body: jsonBody == null ? null : jsonEncode(jsonBody),
    );
  }

  /// PATCH with refresh+retry
  static Future<http.Response> patch(
    String path, {
    Map<String, String>? queryParameters,
    Object? jsonBody,
  }) async {
    final access = await TokenStore.readAccess();
    if (access == null) throw "No access token.";

    final uri = _u(path).replace(queryParameters: queryParameters);

    final res = await http.patch(
      uri,
      headers: _headers(access),
      body: jsonBody == null ? null : jsonEncode(jsonBody),
    );

    if (res.statusCode != 401) return res;

    final newAccess = await _refreshAccessLocked();

    return await http.patch(
      uri,
      headers: _headers(newAccess),
      body: jsonBody == null ? null : jsonEncode(jsonBody),
    );
  }

  /// Multipart photo upload with refresh+retry
  static Future<http.Response> uploadPhoto(String filePath, {String mimeType = 'image/jpeg'}) async {
    final access = await TokenStore.readAccess();
    if (access == null) throw "No access token.";

    final res = await _sendPhotoUpload(filePath, mimeType, access);
    if (res.statusCode != 401) return res;

    final newAccess = await _refreshAccessLocked();
    return _sendPhotoUpload(filePath, mimeType, newAccess);
  }

  /// DELETE photo with refresh+retry
  static Future<http.Response> deletePhoto() async {
    final access = await TokenStore.readAccess();
    if (access == null) throw "No access token.";

    final uri = _u('/api/accounts/me/photo/');
    final res = await http.delete(uri, headers: _headers(access));
    if (res.statusCode != 401) return res;

    final newAccess = await _refreshAccessLocked();
    return http.delete(uri, headers: _headers(newAccess));
  }

  static Future<http.Response> _sendPhotoUpload(String filePath, String mimeType, String token) async {
    final uri = _u('/api/accounts/me/photo/');
    final request = http.MultipartRequest('PATCH', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath(
        'photo',
        filePath,
        contentType: MediaType.parse(mimeType),
      ));
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  /// Ensures only one refresh runs at a time
  static Future<String> _refreshAccessLocked() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = _refreshAccess();

    try {
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  static Future<String> _refreshAccess() async {
    final refresh = await TokenStore.readRefresh();
    if (refresh == null) {
      await AuthState.instance.logout();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
      throw "Session expired. Please log in again.";
    }

    try {
      final newAccess = await AuthApi.refreshAccess(refreshToken: refresh);
      await TokenStore.save(access: newAccess, refresh: refresh);
      return newAccess;
    } catch (e) {
      await AuthState.instance.logout();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
      throw "Session expired. Please log in again.";
    }
  }
}
