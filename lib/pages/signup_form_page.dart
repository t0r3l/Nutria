import 'package:flutter/material.dart';
import 'package:nutria_project/pages/services/user_storage.dart';
import 'package:nutria_project/pages/services/api_service.dart';
import 'preferences_form_page.dart';

class SignupFormPage extends StatefulWidget {
  final bool googleFit;

  const SignupFormPage({super.key, required this.googleFit});

  @override
  State<SignupFormPage> createState() => _SignupFormPageState();
}

class _SignupFormPageState extends State<SignupFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _ageCtrl = TextEditingController();
  final _tailleCtrl = TextEditingController();
  final _poidsCtrl = TextEditingController();

  String gender = 'male';
  String activityLevel = 'moderate';
  String objectif = 'weight loss';

  final genders = ['male', 'female'];
  final activityLevels = ['very low', 'low', 'moderate', 'high', 'very high'];
  final objectifs = ['weight loss', 'maintain', 'weight gain'];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await UserStorage.loadSignup();
    if (data != null) {
      _ageCtrl.text = data['age']?.toString() ?? '';
      _tailleCtrl.text = data['height']?.toString() ?? '';
      _poidsCtrl.text = data['weight_in_kg']?.toString() ?? '';
      gender = data['gender'] ?? 'male';
      activityLevel = data['activity_level'] ?? 'moderate';
      objectif = data['objectif'] ?? 'weight loss';
      setState(() {});
    }
  }

  Future<void> _saveAndFetchTargets() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    final userData = {
      'gender': gender,
      'age': _ageCtrl.text.trim(),
      'height': _tailleCtrl.text.trim(),
      'weight_in_kg': _poidsCtrl.text.trim(),
      'activity_level': activityLevel,
      'objectif': objectif,
    };

    await UserStorage.saveSignup(userData);

    final profileForBackend = {
      'gender': gender,
      'age': int.tryParse(_ageCtrl.text) ?? 0,
      'height': int.tryParse(_tailleCtrl.text) ?? 0,
      'weight_in_kg': double.tryParse(_poidsCtrl.text) ?? 0.0,
      'activity_level': activityLevel,
      'objectif': objectif,
    };

    print('📤 [SignupFormPage] Payload pour API: $profileForBackend');

    try {
      final response = await ApiService.fetchTargets(profileForBackend);
      print('🎯 [SignupFormPage] Réponse targets: $response');

      // 🔷 Prendre uniquement le `target_array`
      final targetArray = response['target_array'];

      if (targetArray is List) {
        await UserStorage.saveTargets(targetArray);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil & targets créés avec succès ✨')),
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PreferencesFormPage()),
        );
      } else {
        throw Exception('La réponse ne contient pas de target_array valide');
      }
    } catch (e) {
      print('🔥 [SignupFormPage] Erreur targets: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du calcul des targets: $e')),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _tailleCtrl.dispose();
    _poidsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer votre compte')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _ageCtrl,
                  decoration: const InputDecoration(labelText: 'Âge'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                  (v == null || v.isEmpty) ? 'Veuillez entrer votre âge' : null,
                ),
                TextFormField(
                  controller: _poidsCtrl,
                  decoration: const InputDecoration(labelText: 'Poids (kg)'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                  (v == null || v.isEmpty) ? 'Veuillez entrer votre poids' : null,
                ),
                TextFormField(
                  controller: _tailleCtrl,
                  decoration: const InputDecoration(labelText: 'Taille (cm)'),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                  (v == null || v.isEmpty) ? 'Veuillez entrer votre taille' : null,
                ),
                DropdownButtonFormField<String>(
                  value: gender,
                  decoration: const InputDecoration(labelText: 'Sexe'),
                  items: genders
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => gender = v!),
                ),
                DropdownButtonFormField<String>(
                  value: activityLevel,
                  decoration: const InputDecoration(labelText: 'Niveau d’activité'),
                  items: activityLevels
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => activityLevel = v!),
                ),
                DropdownButtonFormField<String>(
                  value: objectif,
                  decoration: const InputDecoration(labelText: 'Objectif'),
                  items: objectifs
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => objectif = v!),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isLoading ? null : _saveAndFetchTargets,
                  child: isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Suivant'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
