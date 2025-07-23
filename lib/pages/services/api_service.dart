import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
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


  static Future<dynamic> optimizeMeal({required List<dynamic> targets}) async {
    final url = Uri.parse(
        'https://tztmsbrq2k.execute-api.eu-west-1.amazonaws.com/dev/optimize-meal');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({'targets': targets});

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
}
