import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
    // Copy the picked image into app persistent storage so it survives reinstall/update
    try {
      final src = File(p);
      if (!await src.exists()) return;
      final dir = await getApplicationDocumentsDirectory();
      final avatars = Directory('${dir.path}/avatars');
      if (!await avatars.exists()) {
        await avatars.create(recursive: true);
      }
      String ext = '';
      final dot = p.lastIndexOf('.');
      if (dot != -1 && dot < p.length - 1) {
        ext = p.substring(dot + 1).toLowerCase();
        // Basic sanitize
        if (ext.length > 6) ext = 'jpg';
      } else {
        ext = 'jpg';
      }
      final filename = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final dest = File('${avatars.path}/$filename');
      await src.copy(dest.path);

      // Optionally clean old local avatar if it was stored inside our avatars folder
      if (_avatarType == 'file' && _avatarValue != null) {
        try {
          final old = File(_avatarValue!);
          if (old.path.contains('/avatars/') && await old.exists()) {
            await old.delete();
          }
        } catch (_) {}
      }

      _avatarType = 'file';
      _avatarValue = dest.path;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
      await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
    } catch (_) {
      // Fallback to original path if copy fails (may still be temporary)
      _avatarType = 'file';
      _avatarValue = p;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsAvatarTypeKey, _avatarType!);
      await prefs.setString(_prefsAvatarValueKey, _avatarValue!);
    }
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
