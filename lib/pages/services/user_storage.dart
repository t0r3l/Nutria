import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserStorage {
  static const _signupKey = 'signup';
  static const _weightHistoryKey = 'weight_history';
  static const _preferencesKey = 'preferences';
  static const _targetsKey = 'targets';
  static const _lastProfileKey = 'last_profile_key';

  /// 🔐 Enregistre le profil utilisateur
  static Future<void> saveSignup(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_signupKey, jsonEncode(data));
  }

  /// 📥 Charge le profil utilisateur
  static Future<Map<String, dynamic>?> loadSignup() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_signupKey);
    return jsonStr != null ? jsonDecode(jsonStr) : null;
  }

  /// 📊 Enregistre l’historique des poids
  static Future<void> saveWeightHistory(List<Map<String, dynamic>> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_weightHistoryKey, jsonEncode(history));
  }

  /// 📊 Charge l’historique des poids
  static Future<List<Map<String, dynamic>>?> loadWeightHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_weightHistoryKey);
    if (jsonStr != null) {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  /// ✅ Enregistre les préférences (régime + calorie_split)
  static Future<void> savePreferences(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferencesKey, jsonEncode(data));
  }

  /// ✅ Charge les préférences (régime + calorie_split)
  static Future<Map<String, dynamic>?> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_preferencesKey);
    return jsonStr != null ? jsonDecode(jsonStr) : null;
  }

  /// 🔢 Récupère le pourcentage de calories associé à un repas (ex: 'Déjeuner')
  static Future<int> getCalorieSplitPercent(String momentRepas) async {
    final prefs = await loadPreferences();
    final split = prefs?['calorie_split'] ?? {};
    switch (momentRepas.toLowerCase()) {
      case 'petit-déjeuner':
        return split['petit_dejeuner'] ?? 25;
      case 'déjeuner':
        return split['dejeuner'] ?? 40;
      case 'dîner':
        return split['diner'] ?? 35;
      default:
        return 25;
    }
  }

  /// 🎯 Enregistre les targets nutritionnels
  static Future<void> saveTargets(List<dynamic> targets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_targetsKey, jsonEncode(targets));
  }

  /// 🎯 Charge les targets nutritionnels
  static Future<List<dynamic>?> loadTargets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_targetsKey);
    if (jsonStr != null) {
      return jsonDecode(jsonStr);
    }
    return null;
  }

  /// 🧬 Enregistre la clé du profil
  static Future<void> saveLastProfileKey(String profileKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastProfileKey, profileKey);
  }

  /// 🧬 Charge la dernière clé du profil
  static Future<String?> loadLastProfileKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastProfileKey);
  }
}
