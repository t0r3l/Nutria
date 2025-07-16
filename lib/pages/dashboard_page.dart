import 'package:flutter/material.dart';
import 'profile_page.dart';
import 'composer_meal_page.dart';
import 'preferences_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'Profil') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              } else if (value == 'Composer') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ComposerMealPage()),
                );
              } else if (value == 'Préférences') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PreferencesPage()),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Profil',
                child: Text('Profil'),
              ),
              const PopupMenuItem(
                value: 'Composer',
                child: Text('Composer un repas'),
              ),
              const PopupMenuItem(
                value: 'Préférences',
                child: Text('Préférences'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          /// Fond d’écran
          Image.asset(
            'assets/images/16.png',
            fit: BoxFit.cover,
          ),

          /// Contenu
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: kToolbarHeight + 20),

                /// Logo en haut
                Center(
                  child: Image.asset(
                    'assets/images/ChatGPT Image 8 juil. 2025, 23_37_30.png',
                    width: 100,
                    height: 100,
                  ),
                ),

                const SizedBox(height: 5),

                /// Image décorative avant stats
                Center(
                  child: Image.asset(
                    'assets/images/25.png',
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 20),

                /// Bouton Composer juste après la bannière
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF1F1F23), // anthracite
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ComposerMealPage()),
                      );
                    },
                    icon: const Icon(Icons.restaurant,
                        size: 20, color: Colors.white),
                    label: const Text(
                      '🍽️ Composer un repas',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// Statistiques du jour
                const Text(
                  'Statistiques du jour',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Calories : 1200 / 2000 kcal'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: 1200 / 2000,
                          minHeight: 12,
                          backgroundColor: Colors.grey[300],
                          color: Colors.green,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: const [
                            Chip(label: Text('P: 80g')),
                            Chip(label: Text('L: 50g')),
                            Chip(label: Text('G: 200g')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: const [
                            Column(
                              children: [
                                Text('Poids actuel',
                                    style: TextStyle(color: Colors.grey)),
                                Text('70 kg',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              children: [
                                Text('Poids cible',
                                    style: TextStyle(color: Colors.grey)),
                                Text('65 kg',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// Suivi hebdomadaire
                const Text(
                  'Suivi hebdomadaire',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 3,
                  child: SizedBox(
                    height: 200,
                    child: const Center(child: Text('[Graphique ici]')),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Objectif semaine : 14 000 kcal',
                    style: TextStyle(color: Colors.black),
                  ),
                ),

                const SizedBox(height: 20),

                /// Actions rapides
                const Text(
                  'Actions rapides',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfilePage()),
                          );
                        },
                        icon: const Icon(Icons.person, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Profil',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PreferencesPage()),
                          );
                        },
                        icon: const Icon(Icons.settings, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Préférences',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
