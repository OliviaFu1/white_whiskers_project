class UserStore {
  static String? _ownerName;

  static Future<void> setOwnerName(String name) async {
    _ownerName = name;
  }

  static Future<String?> getOwnerName() async {
    return _ownerName;
  }

  static Future<void> clear() async {
    _ownerName = null;
  }
}