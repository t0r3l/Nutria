import 'package:flutter/material.dart';
import 'package:nutria_project/pages/services/user_storage.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  String? regime;

  /// Régimes conformes à ceux attendus par le backend
  final Map<String, String> regimes = {
    'vegan': 'Vegan',
    'vegetarian': 'Végétarien',
    'halal': 'Halal',
    'kosher': 'Casher',
    'gluten-free': 'Sans gluten',
    'organic': 'Bio',
    'sans régime':'Sans Régime'
  };

  bool isLoading = true;

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
        isLoading = false;
      });
    } else {
      setState(() {
        regime = regimes.keys.first;
        isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    await UserStorage.savePreferences({
      'regime': regime,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Préférences mises à jour')),
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

            ElevatedButton(
              onPressed: () async {
                await _savePreferences();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}