// ✅ Nouvelle version de ComposerMealPage avec gestion de target_legumes et regime selon le moment du repas
import 'package:flutter/material.dart';
import 'package:nutria_project/pages/services/user_storage.dart';
import 'package:nutria_project/pages/services/api_service.dart';
import 'dart:developer';

class ComposerMealPage extends StatefulWidget {
  const ComposerMealPage({super.key});

  @override
  State<ComposerMealPage> createState() => _ComposerMealPageState();
}

class _ComposerMealPageState extends State<ComposerMealPage> {
  String? momentRepas = 'Déjeuner';
  bool repasGenere = false;
  double progress = 0.6;
  Map<String, dynamic>? repasGenereData;

  Future<void> _generateMeal() async {
    final userProfile = await UserStorage.loadSignup();
    if (userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil utilisateur non trouvé.')),
      );
      return;
    }

    final percent = await UserStorage.getCalorieSplitPercent(momentRepas ?? 'Déjeuner');
    final allTargets = await UserStorage.loadTargets();
    if (allTargets == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun objectif nutritionnel trouvé.')),
      );
      return;
    }

    final preferences = await UserStorage.loadPreferences();
    final String regime = preferences?['regime'] ?? 'sans régime';

    final portionMeal = allTargets.map((n) => n * (percent / 100)).toList();
    final int targetLegumes = momentRepas == 'Petit-déjeuner' ? 0 : 100;

    try {
      final optimizedMeal = await ApiService.optimizeMeal(
        targets: portionMeal,
        targetLegumes: targetLegumes,
        regime: regime,
      );
      setState(() {
        repasGenere = true;
        repasGenereData = optimizedMeal;
      });
    } catch (e) {
      log('Erreur de génération du repas : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la génération du repas.')),
      );
    }
  }

  Widget buildMealCard(Map<String, dynamic> mealData) {
    final mealPlan = List<Map<String, dynamic>>.from(mealData['meal_plan'] ?? []);
    final obtained = List<double>.from(mealData['verification']?['obtained'] ?? []);
    final targets = List<double>.from(mealData['verification']?['targets'] ?? []);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🥗 Composition du repas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...mealPlan.map((item) => Text(
              '• ${item['product_name']} - ${item['quantité_g'].toStringAsFixed(1)} g',
              style: const TextStyle(fontSize: 14),
            )),
            const SizedBox(height: 16),
            const Text('🔥 Macros obtenues vs. objectifs :', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Calories : ${obtained[0].toStringAsFixed(0)} / ${targets[0].toStringAsFixed(0)} kcal'),
            Text('Protéines : ${obtained[1].toStringAsFixed(1)} / ${targets[1].toStringAsFixed(1)} g'),
            Text('Glucides : ${obtained[2].toStringAsFixed(1)} / ${targets[2].toStringAsFixed(1)} g'),
            Text('Lipides : ${obtained[3].toStringAsFixed(1)} / ${targets[3].toStringAsFixed(1)} g'),
            Text('Fibres : ${obtained[4].toStringAsFixed(1)} / ${targets[4].toStringAsFixed(1)} g'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/17.png',
            fit: BoxFit.cover,
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: kToolbarHeight + 20),
                Center(
                  child: Image.asset(
                    'assets/images/ChatGPT Image 8 juil. 2025, 23_37_32.png',
                    width: 100,
                    height: 100,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '🍳 Compose ton repas parfait',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nous générons un repas adapté à tes objectifs, tes préférences et ton budget calorique du jour.',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
                Image.asset(
                  'assets/images/14.png',
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Choisir le moment du repas',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Column(
                  children: ['Petit-déjeuner', 'Déjeuner', 'Dîner']
                      .map(
                        (moment) => RadioListTile<String>(
                      title: Text(moment, style: const TextStyle(color: Colors.white)),
                      value: moment,
                      groupValue: momentRepas,
                      onChanged: (val) {
                        setState(() {
                          momentRepas = val;
                        });
                      },
                    ),
                  )
                      .toList(),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _generateMeal,
                    icon: const Icon(Icons.autorenew),
                    label: const Text('Générer mon repas'),
                  ),
                ),
                const SizedBox(height: 20),
                if (repasGenere && repasGenereData != null) ...[
                  const Divider(),
                  const Text(
                    '📋 Détails du repas',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  buildMealCard(repasGenereData!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}