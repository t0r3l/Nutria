import 'package:flutter/material.dart';
import 'package:nutria_project/pages/services/user_storage.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  String? regime;
  int petitDejPourcent = 25;
  int dejPourcent = 40;
  int dinerPourcent = 35;
  bool isLoading = true;

  final Map<String, String> regimes = {
    'vegan': 'Vegan',
    'vegetarian': 'Végétarien',
    'halal': 'Halal',
    'kosher': 'Casher',
    'gluten-free': 'Sans gluten',
    'organic': 'Bio',
    'sans régime': 'Sans Régime'
  };

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final data = await UserStorage.loadPreferences();
    if (data != null) {
      setState(() {
        regime = data['regime'];
        final split = data['calorie_split'] ?? {};
        petitDejPourcent = split['petit_dejeuner'] ?? 25;
        dejPourcent = split['dejeuner'] ?? 40;
        dinerPourcent = split['diner'] ?? 35;
        isLoading = false;
      });
    } else {
      regime = regimes.keys.first;
      isLoading = false;
    }
  }

  Future<void> _savePreferences() async {
    final total = petitDejPourcent + dejPourcent + dinerPourcent;
    if (total != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La somme doit faire 100%')),
      );
      return;
    }

    await UserStorage.savePreferences({
      'regime': regime,
      'calorie_split': {
        'petit_dejeuner': petitDejPourcent,
        'dejeuner': dejPourcent,
        'diner': dinerPourcent,
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Préférences mises à jour')),
    );
  }

  Widget buildPourcentageField(String label, int value, Function(int) onChanged) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: '$label (%)'),
      onChanged: (val) => onChanged(int.tryParse(val) ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mes Préférences')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: regime,
              items: regimes.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              decoration: const InputDecoration(labelText: 'Régime'),
              onChanged: (val) => setState(() => regime = val),
            ),
            const SizedBox(height: 30),
            const Text('Répartition des calories (somme = 100%)', style: TextStyle(fontWeight: FontWeight.bold)),

            buildPourcentageField('Petit-déjeuner', petitDejPourcent,
                    (val) => setState(() => petitDejPourcent = val)),
            buildPourcentageField('Déjeuner', dejPourcent,
                    (val) => setState(() => dejPourcent = val)),
            buildPourcentageField('Dîner', dinerPourcent,
                    (val) => setState(() => dinerPourcent = val)),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _savePreferences,
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
