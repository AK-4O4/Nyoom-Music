import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _storagePathKey = 'storage_path';
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  Future<void> setStoragePath(String path) async {
    await _prefs.setString(_storagePathKey, path);
  }

  String? getStoragePath() {
    return _prefs.getString(_storagePathKey);
  }

  Future<void> clearStoragePath() async {
    await _prefs.remove(_storagePathKey);
  }
}
