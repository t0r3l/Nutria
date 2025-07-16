import 'package:flutter/material.dart';

class ComposerMealPage extends StatefulWidget {
  const ComposerMealPage({super.key});

  @override
  State<ComposerMealPage> createState() => _ComposerMealPageState();
}

class _ComposerMealPageState extends State<ComposerMealPage> {
  String? momentRepas = 'Déjeuner';
  bool repasGenere = false;
  double progress = 0.6;

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
          /// 📷 Fond d’écran
          Image.asset(
            'assets/images/17.png',
            fit: BoxFit.cover,
          ),

          /// 📄 Contenu
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: kToolbarHeight + 20),

                /// 📛 Logo
                Center(
                  child: Image.asset(
                    'assets/images/ChatGPT Image 8 juil. 2025, 23_37_32.png',
                    width: 100,
                    height: 100,
                  ),
                ),

                const SizedBox(height: 20),

                /// 📋 En-tête
                const Text(
                  '🍳 Compose ton repas parfait',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nous générons un repas adapté à tes objectifs, tes préférences et ton budget calorique du jour.',
                  style: TextStyle(color: Colors.white),
                ),

                /// 📷 Image décorative après en-tête
                const SizedBox(height: 20),
                Image.asset(
                  'assets/images/14.png',
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),

                const SizedBox(height: 20),

                /// 📋 Moment du repas
                const Text(
                  'Choisir le moment du repas',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Column(
                  children: ['Petit-déjeuner', 'Déjeuner', 'Dîner', 'Snack']
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

                /// 🔄 Bouton Générer
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        repasGenere = true;
                      });
                    },
                    icon: const Icon(Icons.autorenew),
                    label: const Text('Générer mon repas'),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Basé sur tes préférences, restrictions et ton objectif nutritionnel.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),

                const SizedBox(height: 20),

                /// 📋 Résultat généré
                if (repasGenere) ...[
                  const Divider(),

                  const Text(
                    '📋 Détails du repas',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),

                  /// 📷 Image décorative après *Détails du repas*
                  const SizedBox(height: 12),
                  Image.asset(
                    'assets/images/1.png',
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),

                  Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🥗 Salade de quinoa & poulet grillé',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          /// 📝 Ingrédients
                          const Text(
                            '📝 Ingrédients :',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text('- Quinoa\n- Poulet\n- Légumes variés\n- Huile d’olive'),

                          const SizedBox(height: 12),

                          /// 🔥 Calories & macros
                          const Text(
                            '🔥 Calories et macros :',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text('Calories : 450 kcal'),
                          const Text('Protéines : 30g'),
                          const Text('Glucides : 50g'),
                          const Text('Lipides : 15g'),

                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ajouté aux favoris !'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.favorite_border),
                                label: const Text('Ajouter aux favoris'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    repasGenere = false;
                                  });
                                },
                                icon: const Icon(Icons.autorenew),
                                label: const Text('Générer un autre'),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                onPressed: () {
                                  setState(() {
                                    progress += 0.2;
                                    if (progress > 1.0) progress = 1.0;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Repas choisi et ajouté à la journée !'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Choisir ce repas'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// 📊 Statut du jour
                  const Text(
                    '📊 Statut du jour',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                    backgroundColor: Colors.grey[300],
                    color: Colors.green,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Il te reste : ${(1.0 - progress) * 1500 ~/ 1} kcal / ${(1.0 - progress) * 50 ~/ 1}g protéines / ${(1.0 - progress) * 20 ~/ 1}g lipides pour la journée.',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
