// ✅ Nouvelle version complète de ApiService avec calorie_percent intégré
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nutria_project/pages/services/user_storage.dart';

class ApiService {
  /// 🔥 Envoie les infos pour calculer les targets (TDEE + macros)
  static Future<dynamic> fetchTargets(Map<String, dynamic> userData) async {
    final url = Uri.parse(
        'https://tztmsbrq2k.execute-api.eu-west-1.amazonaws.com/dev/targets');
    final headers = {'Content-Type': 'application/json'};
    final body = {
      'gender': userData['gender'],
      'age': userData['age'],
      'height': userData['height'],
      'weight_in_kg': userData['weight_in_kg'],
      'activity_level': userData['activity_level'],
      'objectif': userData['objectif'],
    };

    print('📤 [fetchTargets] Payload envoyé : ${jsonEncode(body)}');

    try {
      final response =
      await http.post(url, headers: headers, body: jsonEncode(body));

      print(
          '📥 [fetchTargets] Réponse (${response.statusCode}) : ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ [fetchTargets] Décodé avec succès');
        return data;
      } else {
        throw Exception(
            'Erreur fetchTargets (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('🔥 [fetchTargets] Exception : $e');
      rethrow;
    }
  }

  /// 🍽️ Génère un repas optimisé à partir des targets
  static Future<dynamic> optimizeMeal({required List<dynamic> targets,required int targetLegumes,
    required String regime}) async {
    final url = Uri.parse(
        'http://34.245.111.159:8080/optimize');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      "user": {
        "target_array": targets,
      },
      "meal_fraction": 1,
      "solveur": "hybride",
      "sample_size": 1000,
      "target_legumes":targetLegumes ,
      "regime": regime,
    });

    print('📤 [optimizeMeal] Payload envoyé : $body');

    try {
      final response = await http.post(url, headers: headers, body: body);

      print(
          '📥 [optimizeMeal] Réponse (${response.statusCode}) : ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ [optimizeMeal] Décodé avec succès');
        return data;
      } else {
        throw Exception(
            'Erreur optimizeMeal (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      print('🔥 [optimizeMeal] Exception : $e');
      rethrow;
    }
  }

  /// 🔁 Envoie user_id + calorie_percent à Flask (si tu veux interagir avec ton backend directement)
  static Future<dynamic> generateMealWithCaloriePercent(int caloriePercent) async {
    final user = await UserStorage.loadSignup();
    if (user == null) throw Exception('Utilisateur non trouvé');

    final url = Uri.parse('http://localhost:5000/generate-meal');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'user_id': user,
      'calorie_percent': caloriePercent,
    });

    print('📤 [generateMeal] Payload : $body');

    try {
      final response = await http.post(url, headers: headers, body: body);
      print('📥 [generateMeal] Réponse (${response.statusCode}) : ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur génération repas : ${response.body}');
      }
    } catch (e) {
      print('🔥 [generateMeal] Exception : $e');
      rethrow;
    }
  }
}
