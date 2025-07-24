import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:nutria_project/pages/services/api_service.dart';
import 'package:nutria_project/pages/services/user_storage.dart';
import 'composer_meal_page.dart';
import 'profile_page.dart';
import 'preferences_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> weightHistory = [];
  List<dynamic> userTargets = [];
  Map<String, double> dailyCaloriesMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final history = await UserStorage.loadWeightHistory();
    final profile = await UserStorage.loadSignup();
    final savedTargets = await UserStorage.loadTargets();
    final lastProfileKey = await UserStorage.loadLastProfileKey();

    if (profile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil incomplet. Veuillez le remplir.')),
        );
      }
      return;
    }

    final profileKey = jsonEncode(profile);
    if (profileKey != lastProfileKey || savedTargets == null || savedTargets.isEmpty) {
      final profileForBackend = {
        'gender': profile['gender'],
        'age': int.tryParse(profile['age']?.toString() ?? '') ?? 0,
        'height': int.tryParse(profile['height']?.toString() ?? '') ?? 0,
        'weight_in_kg': double.tryParse(profile['weight_in_kg']?.toString() ?? '') ?? 0.0,
        'activity_level': profile['activity_level'],
        'objectif': profile['objectif'],
      };
      try {
        final response = await ApiService.fetchTargets(profileForBackend);
        final rawList = response['target_array'];
        if (rawList is! List) throw Exception('Réponse API invalide : pas de target_array');

        final targets = rawList.map((e) => (e as num).toDouble()).toList();
        await UserStorage.saveTargets(targets);
        await UserStorage.saveLastProfileKey(profileKey);
        setState(() => userTargets = targets);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur targets: $e')),
          );
        }
      }
    } else {
      setState(() => userTargets = savedTargets);
    }

    setState(() => weightHistory = history ?? []);
    await _loadConsumedMeals();
  }

  Future<void> _loadConsumedMeals() async {
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final lastDate = await UserStorage.loadLastConsumedDate();

    if (lastDate != todayKey) {
      await UserStorage.clearConsumedMeals();
      await UserStorage.saveLastConsumedDate(todayKey);
    }

    final meals = await UserStorage.loadConsumedMeals() ?? [];
    final Map<String, double> tempMap = {};

    for (var meal in meals) {
      final date = DateTime.tryParse(meal['timestamp'] ?? '');
      if (date == null) continue;

      final key = DateFormat('yyyy-MM-dd').format(date);
      final calories = (meal['macros']?['calories'] ?? 0).toDouble();
      if (calories <= 0) continue;

      tempMap.update(key, (value) => value + calories, ifAbsent: () => calories);
    }

    setState(() => dailyCaloriesMap = tempMap);
  }

  Widget _buildTargetCard(String label, String value) => Expanded(
    child: Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    ),
  );

  Widget _buildCaloriesList() {
    if (dailyCaloriesMap.isEmpty) {
      return const Text('Aucun repas consommé pour l’instant.');
    }

    final entries = dailyCaloriesMap.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Column(
      children: entries.map((entry) {
        final date = entry.key;
        final calories = entry.value.toStringAsFixed(0);
        return Card(
          color: Colors.white.withOpacity(0.95),
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: const Icon(Icons.local_fire_department, color: Colors.orange),
            title: Text('Le $date', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$calories kcal consommées'),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weeklyCaloriesTarget =
    userTargets.isNotEmpty ? (userTargets[0] as num) * 7 : null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'Profil':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()))
                      .then((_) => _loadData());
                  break;
                case 'Composer':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ComposerMealPage()))
                      .then((_) => _loadConsumedMeals());
                  break;
                case 'Préférences':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PreferencesPage()))
                      .then((_) => _loadData());
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Profil', child: Text('Profil')),
              const PopupMenuItem(value: 'Composer', child: Text('Composer un repas')),
              const PopupMenuItem(value: 'Préférences', child: Text('Préférences')),
            ],
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/16.png', fit: BoxFit.cover),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: kToolbarHeight + 20),
                Center(child: Image.asset('assets/images/ChatGPT Image 8 juil. 2025, 23_37_30.png', width: 100, height: 100)),
                const SizedBox(height: 5),
                Center(child: Image.asset('assets/images/22.png', width: double.infinity, height: 200, fit: BoxFit.cover)),
                const SizedBox(height: 20),

                if (userTargets.isNotEmpty) ...[
                  const Text('🌟 Objectifs (par jour)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      Row(
                        children: [
                          _buildTargetCard('Calories', '${(userTargets[0] as num).toStringAsFixed(0)} kcal'),
                          _buildTargetCard('Protéines', '${(userTargets[1] as num).toStringAsFixed(1)} g'),
                        ],
                      ),
                      Row(
                        children: [
                          _buildTargetCard('Lipides', '${(userTargets[2] as num).toStringAsFixed(1)} g'),
                          _buildTargetCard('Glucides', '${(userTargets[3] as num).toStringAsFixed(1)} g'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ComposerMealPage()))
                          .then((_) => _loadConsumedMeals());
                    },
                    child: const Center(
                      child: Text('🍽️ Composer un repas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  if (weeklyCaloriesTarget != null) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: Text('Objectif hebdomadaire : ${weeklyCaloriesTarget.toStringAsFixed(0)} kcal',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],

                const Text('🔥 Suivi journalier (calories consommées)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildCaloriesList(),
                const SizedBox(height: 20),

                const Text('📈 Suivi du poids', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Card(
                  elevation: 3,
                  child: SizedBox(
                    height: 200,
                    child: weightHistory.isEmpty
                        ? const Center(child: Text('Aucune donnée de poids'))
                        : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: LineChart(
                        LineChartData(
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: weightHistory
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(
                                e.key.toDouble(),
                                double.tryParse(
                                  e.value['poids']?.toString() ??
                                      e.value['weight']?.toString() ??
                                      '0.0',
                                ) ??
                                    0.0,
                              ))
                                  .toList(),
                              isCurved: true,
                              barWidth: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 80),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person_outline),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage())),
                    ),
                    IconButton(
                      icon: const Icon(Icons.fastfood_outlined),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ComposerMealPage())),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PreferencesPage())),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
