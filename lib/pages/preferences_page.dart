import 'package:flutter/material.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  String? selectedRegime;
  final TextEditingController autreRegimeController = TextEditingController();
  final TextEditingController autresAllergiesController = TextEditingController();

  final TextEditingController alimentsPasAimesController = TextEditingController();
  final List<String> alimentsPasAimes = [];

  final TextEditingController alimentsFavorisController = TextEditingController();
  final List<String> alimentsFavoris = [];

  int repasParJour = 3;
  final Map<String, bool> allergies = {};
  final Map<String, bool> restrictionsCulturelles = {};

  final List<String> regimes = [
    'Omnivore', 'Végétarien', 'Végétalien / Vegan', 'Pescétarien',
    'Flexitarien', 'Sans porc', 'Casher', 'Halal','Autre'
  ];

  final List<String> allergiesList = [
    'Gluten', 'Lactose', 'Fruits à coque', 'Œufs', 'Soja', 'Fruits de mer / crustacés'
  ];

  final List<String> restrictionsList = [
    'Ne consomme pas d’alcool', 'Ne consomme pas de bœuf',
    'Ne consomme pas de porc', 'Ne consomme pas de crustacés'
  ];

  @override
  void initState() {
    super.initState();
    for (var allergie in allergiesList) {
      allergies[allergie] = false;
    }
    for (var r in restrictionsList) {
      restrictionsCulturelles[r] = false;
    }
  }

  void addItem(List<String> list, TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        list.add(text);
        controller.clear();
      });
    }
  }

  void removeItem(List<String> list, int index) {
    setState(() {
      list.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Préférences & restrictions')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 1. Régime
            const Text('🍽️ Type de régime', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButtonFormField<String>(
              value: selectedRegime,
              items: regimes.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (val) {
                setState(() {
                  selectedRegime = val;
                });
              },
              decoration: const InputDecoration(hintText: 'Sélectionne ton régime'),
            ),
            if (selectedRegime == 'Autre')
              TextField(
                controller: autreRegimeController,
                decoration: const InputDecoration(labelText: 'Précise ton régime'),
              ),

            const SizedBox(height: 20),

            /// 2. Allergies
            const Text('🚫 Allergies & intolérances', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: allergies.entries.map((entry) {
                return FilterChip(
                  label: Text(entry.key),
                  selected: entry.value,
                  onSelected: (val) {
                    setState(() {
                      allergies[entry.key] = val;
                    });
                  },
                );
              }).toList(),
            ),
            TextField(
              controller: autresAllergiesController,
              decoration: const InputDecoration(labelText: 'Autres allergies'),
            ),

            const SizedBox(height: 20),

            /// 3. Aliments non aimés
            const Text('👎 Aliments que tu n’aimes pas', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: alimentsPasAimesController,
                    decoration: const InputDecoration(
                      hintText: 'Ex : brocoli, foie...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => addItem(alimentsPasAimes, alimentsPasAimesController),
                )
              ],
            ),
            Wrap(
              spacing: 8,
              children: alimentsPasAimes.asMap().entries.map((entry) {
                return Chip(
                  label: Text(entry.value),
                  onDeleted: () => removeItem(alimentsPasAimes, entry.key),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            /// 4. Aliments favoris
            const Text('❤️ Aliments favoris', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: alimentsFavorisController,
                    decoration: const InputDecoration(
                      hintText: 'Ex : poulet, avocat...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => addItem(alimentsFavoris, alimentsFavorisController),
                )
              ],
            ),
            Wrap(
              spacing: 8,
              children: alimentsFavoris.asMap().entries.map((entry) {
                return Chip(
                  label: Text(entry.value),
                  onDeleted: () => removeItem(alimentsFavoris, entry.key),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            /// 5. Nombre & horaires de repas
            const Text('⏰ Nombre de repas/jour', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [3, 4, 5].map((n) {
                return Expanded(
                  child: RadioListTile<int>(
                    title: Text('$n'),
                    value: n,
                    groupValue: repasParJour,
                    onChanged: (val) {
                      setState(() {
                        repasParJour = val!;
                      });
                    },
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            /// 6. Restrictions culturelles ou religieuses
            const Text('📋 Restrictions culturelles/religieuses',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: restrictionsCulturelles.entries.map((entry) {
                return FilterChip(
                  label: Text(entry.key),
                  selected: entry.value,
                  onSelected: (val) {
                    setState(() {
                      restrictionsCulturelles[entry.key] = val;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            /// Enregistrer
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // TODO: enregistrer les données
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Préférences enregistrées')),
                  );
                },
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
