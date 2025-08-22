import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/assistant.dart';

class AssistantProvider extends ChangeNotifier {
  static const String _assistantsKey = 'assistants_v1';
  static const String _currentAssistantKey = 'current_assistant_id_v1';

  final List<Assistant> _assistants = <Assistant>[];
  String? _currentAssistantId;

  List<Assistant> get assistants => List.unmodifiable(_assistants);
  String? get currentAssistantId => _currentAssistantId;
  Assistant? get currentAssistant => _assistants.firstWhere((a) => a.id == _currentAssistantId, orElse: () => _assistants.isNotEmpty ? _assistants.first : _defaultAssistant());

  AssistantProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_assistantsKey);
    if (raw != null && raw.isNotEmpty) {
      _assistants
        ..clear()
        ..addAll(Assistant.decodeList(raw));
    }
    // Ensure at least one default assistant exists
    if (_assistants.isEmpty) {
      _assistants.add(_defaultAssistant());
      await _persist();
    }
    _currentAssistantId = prefs.getString(_currentAssistantKey) ?? _assistants.first.id;
    notifyListeners();
  }

  Assistant _defaultAssistant() => Assistant(
        id: const Uuid().v4(),
        name: 'Kelivo',
        systemPrompt: '',
        deletable: false,
        thinkingBudget: null,
      );

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString( _assistantsKey, Assistant.encodeList(_assistants));
  }

  Future<void> setCurrentAssistant(String id) async {
    if (_currentAssistantId == id) return;
    _currentAssistantId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentAssistantKey, id);
  }

  Assistant? getById(String id) {
    final idx = _assistants.indexWhere((a) => a.id == id);
    if (idx == -1) return null;
    return _assistants[idx];
  }

  Future<String> addAssistant({String? name}) async {
    final a = Assistant(id: const Uuid().v4(), name: (name ?? '新助手'));
    _assistants.add(a);
    await _persist();
    notifyListeners();
    return a.id;
  }

  Future<void> updateAssistant(Assistant updated) async {
    final idx = _assistants.indexWhere((a) => a.id == updated.id);
    if (idx == -1) return;
    _assistants[idx] = updated;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteAssistant(String id) async {
    final idx = _assistants.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    if (!_assistants[idx].deletable) return; // default not deletable
    final removingCurrent = _assistants[idx].id == _currentAssistantId;
    _assistants.removeAt(idx);
    if (removingCurrent) {
      _currentAssistantId = _assistants.isNotEmpty ? _assistants.first.id : null;
    }
    await _persist();
    final prefs = await SharedPreferences.getInstance();
    if (_currentAssistantId != null) {
      await prefs.setString(_currentAssistantKey, _currentAssistantId!);
    } else {
      await prefs.remove(_currentAssistantKey);
    }
    notifyListeners();
  }
}
