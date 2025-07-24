import 'package:flutter/material.dart';
import 'package:nutria_project/pages/services/user_storage.dart';
import 'package:nutria_project/pages/services/api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _poidsCtrl = TextEditingController();
  final _tailleCtrl = TextEditingController();

  String sexe = 'male';
  String objectif = 'weight loss';
  String activityLevel = 'moderate';

  final sexes = ['male', 'female'];
  final activityLevels = ['very low', 'low', 'moderate', 'high', 'very high'];
  final objectifs = ['weight loss', 'maintain', 'weight gain'];

  List<Map<String, dynamic>> historiquePoids = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final data = await UserStorage.loadSignup();
    final history = await UserStorage.loadWeightHistory();

    if (data != null) {
      _nomCtrl.text = data['nom'] ?? '';
      _prenomCtrl.text = data['prenom'] ?? '';
      _ageCtrl.text = data['age']?.toString() ?? '';
      _poidsCtrl.text = data['weight_in_kg']?.toString() ?? '';
      _tailleCtrl.text = data['height']?.toString() ?? '';
      sexe = data['gender'] ?? 'male';
      activityLevel = data['activity_level'] ?? 'moderate';
      objectif = data['objectif'] ?? 'weight loss';
    }

    if (history != null) {
      historiquePoids = history;
    }

    setState(() {});
  }

  Future<void> enregistrerProfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final now = DateTime.now().toIso8601String().substring(0, 10);
    final poidsActuel = double.tryParse(_poidsCtrl.text) ?? 0.0;
    historiquePoids.add({'date': now, 'poids': poidsActuel});

    final userData = {
      'nom': _nomCtrl.text.trim(),
      'prenom': _prenomCtrl.text.trim(),
      'age': int.tryParse(_ageCtrl.text) ?? 0,
      'height': int.tryParse(_tailleCtrl.text) ?? 0,
      'weight_in_kg': poidsActuel,
      'gender': sexe,
      'activity_level': activityLevel,
      'objectif': objectif,
    };

    await UserStorage.saveSignup(userData);
    await UserStorage.saveWeightHistory(historiquePoids);

    final profileForBackend = {
      'gender': userData['gender'],
      'age': userData['age'],
      'height': userData['height'],
      'weight_in_kg': userData['weight_in_kg'],
      'activity_level': userData['activity_level'],
      'objectif': userData['objectif'],
    };

    try {
      final targets = await ApiService.fetchTargets(profileForBackend);
      await UserStorage.saveTargets(targets);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Profil et targets mis à jour !')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur lors du calcul des targets : $e')),
      );
    }

    setState(() => isLoading = false);
  }

  Future<void> resetAllData() async {
    await UserStorage.saveSignup({});
    await UserStorage.saveWeightHistory([]);
    await UserStorage.clearMealLogs();
    await UserStorage.savePreferences({});
    await UserStorage.saveTargets([]);
    await UserStorage.saveLastProfileKey('');
    await UserStorage.saveLastConsumedDate('');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🧹 Toutes les données ont été réinitialisées')),
    );
    _loadUserData(); // Recharge interface vide
  }

  Future<void> _deleteEntry(int index) async {
    historiquePoids.removeAt(index);
    await UserStorage.saveWeightHistory(historiquePoids);
    setState(() {});
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _ageCtrl.dispose();
    _poidsCtrl.dispose();
    _tailleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('👤 Mon Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Informations personnelles',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nomCtrl,
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _prenomCtrl,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Âge'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: sexe,
                      decoration: const InputDecoration(labelText: 'Sexe'),
                      items: sexes
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) => setState(() => sexe = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _poidsCtrl,
                keyboardType: TextInputType.number,
                decoration:
                const InputDecoration(labelText: 'Poids actuel (kg)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _tailleCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Taille (cm)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: activityLevel,
                decoration:
                const InputDecoration(labelText: 'Niveau d’activité'),
                items: activityLevels
                    .map((lvl) =>
                    DropdownMenuItem(value: lvl, child: Text(lvl)))
                    .toList(),
                onChanged: (val) => setState(() => activityLevel = val!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: objectif,
                decoration: const InputDecoration(labelText: 'Objectif'),
                items: objectifs
                    .map((obj) =>
                    DropdownMenuItem(value: obj, child: Text(obj)))
                    .toList(),
                onChanged: (val) => setState(() => objectif = val!),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: isLoading
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Enregistrer les modifications'),
                  onPressed: isLoading ? null : enregistrerProfil,
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text(
                    'Réinitialiser toutes les données',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: resetAllData,
                ),
              ),
              const SizedBox(height: 20),
              if (historiquePoids.isNotEmpty) ...[
                const Text('Historique des poids',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: historiquePoids.length,
                  itemBuilder: (context, index) {
                    final entry = historiquePoids.reversed.toList()[index];
                    return Dismissible(
                      key: ValueKey(entry['date']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        final actualIndex = historiquePoids.length - 1 - index;
                        _deleteEntry(actualIndex);
                      },
                      child: ListTile(
                        leading: const Icon(Icons.monitor_weight),
                        title: Text('${entry['poids']} kg'),
                        subtitle: Text('Date : ${entry['date']}'),
                      ),
                    );
                  },
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
