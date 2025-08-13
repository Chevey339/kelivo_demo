import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  static const String _prefsUserNameKey = 'user_name';
  static const String _prefsAvatarTypeKey = 'avatar_type'; // emoji | url | file | null
  static const String _prefsAvatarValueKey = 'avatar_value';

  String _name = '用户';
  String get name => _name;

  String? _avatarType; // 'emoji', 'url', 'file'
  String? _avatarValue;
  String? get avatarType => _avatarType;
  String? get avatarValue => _avatarValue;

  UserProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getString(_prefsUserNameKey);
    if (n != null && n.isNotEmpty) {
      _name = n;
      notifyListeners();
    }
    _avatarType = prefs.getString(_prefsAvatarTypeKey);
    _avatarValue = prefs.getString(_prefsAvatarValueKey);
    // Only notify if avatar exists; otherwise rely on name notify above
    if (_avatarType != null && _avatarValue != null) {
      notifyListeners();
    }
  }

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == _name) return;
    _name = trimmed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUserNameKey, _name);
  }

  Future<void> setAvatarEmoji(String emoji) async {
    final e = emoji.trim();
    if (e.isEmpty) return;
    _avatarType = 'emoji';
    _avatarValue = e;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
    await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
  }

  Future<void> setAvatarUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    _avatarType = 'url';
    _avatarValue = u;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
    await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
  }

  Future<void> setAvatarFilePath(String path) async {
    final p = path.trim();
    if (p.isEmpty) return;
    _avatarType = 'file';
    _avatarValue = p;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
    await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
  }

  Future<void> resetAvatar() async {
    _avatarType = null;
    _avatarValue = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsAvatarTypeKey);
    await prefs.remove(_prefsAvatarValueKey);
  }
}
