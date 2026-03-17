import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  static const _storage = FlutterSecureStorage();

  static const _kAccess = "access_token";
  static const _kRefresh = "refresh_token";

  static Future<void> save({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }
  static Future<void> saveAccessToken(String access) async {
    await _storage.write(key: _kAccess, value: access);
  }
  static Future<String?> readAccess() => _storage.read(key: _kAccess);
  static Future<String?> readRefresh() => _storage.read(key: _kRefresh);

  static Future<void> clear() async {
    try {
      await _storage.deleteAll();
    } catch (_) {
      // Windows file-locking fallback: overwrite with null
      await _storage.write(key: _kAccess, value: null);
      await _storage.write(key: _kRefresh, value: null);
    }
  }
}