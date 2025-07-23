import 'package:flutter/material.dart';
import 'package:nutria_project/pages/services/user_storage.dart';
import 'dashboard_page.dart';

class PreferencesFormPage extends StatefulWidget {
  const PreferencesFormPage({super.key});

  @override
  State<PreferencesFormPage> createState() => _PreferencesFormPageState();
}

class _PreferencesFormPageState extends State<PreferencesFormPage> {
  String? regime;
  bool isLoading = true;

  /// Seuls les régimes acceptés par le backend
  final Map<String, String> regimes = {
    'vegan': 'Vegan',
    'vegetarian': 'Végétarien',
    'halal': 'Halal',
    'kosher': 'Casher',
    'gluten-free': 'Sans gluten',
    'organic': 'Bio',
    'sans régime' : 'Sans régime'
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
        isLoading = false;
      });
    } else {
      setState(() {
        regime = null;
        isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    await UserStorage.savePreferences({
      'regime': regime,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Préférences enregistrées ✨')),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
          (route) => false,
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
      appBar: AppBar(title: const Text('Préférences Alimentaires')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: regime,
              items: regimes.entries
                  .map((entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              ))
                  .toList(),
              decoration: const InputDecoration(labelText: 'Régime'),
              onChanged: (val) => setState(() => regime = val),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _savePreferences,
              child: const Text('Terminer'),
            ),
          ],
        ),
      ),
    );
  }
}
