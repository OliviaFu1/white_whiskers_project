import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PetStore {
  static const _storage = FlutterSecureStorage();
  static const _kCurrentPetId = "current_pet_id";

  static int? _cachedPetId;

  // Serializes writes so concurrent calls don't cause file-lock conflicts
  static Future<void> _lastWrite = Future.value();

  static Future<void> setCurrentPetId(int petId) {
    _cachedPetId = petId;
    _lastWrite = _lastWrite
        .catchError((_) {}) // keep the chain alive even if a previous write failed
        .then((_) => _storage.write(key: _kCurrentPetId, value: petId.toString()));
    return _lastWrite;
  }

  static Future<int?> getCurrentPetId() async {
    if (_cachedPetId != null) return _cachedPetId;

    final value = await _storage.read(key: _kCurrentPetId);
    if (value == null) return null;

    final parsed = int.tryParse(value);
    _cachedPetId = parsed;
    return parsed;
  }

  static Future<void> clear() async {
    _cachedPetId = null;
    await _storage.delete(key: _kCurrentPetId);
  }
}