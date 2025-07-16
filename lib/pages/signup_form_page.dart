import 'package:flutter/material.dart';
import 'preferences_form_page.dart';

class SignupFormPage extends StatefulWidget {
  final bool googleFit;

  const SignupFormPage({super.key, required this.googleFit});

  @override
  State<SignupFormPage> createState() => _SignupFormPageState();
}

class _SignupFormPageState extends State<SignupFormPage> {
  final _formKey = GlobalKey<FormState>();

  String? nom, prenom, age, taille, poids, sexe, email, password;

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
                  decoration: const InputDecoration(labelText: 'Nom'),
                  onSaved: (v) => nom = v,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Prénom'),
                  onSaved: (v) => prenom = v,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Âge'),
                  keyboardType: TextInputType.number,
                  onSaved: (v) => age = v,
                ),
                if (!widget.googleFit)
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Poids (kg)'),
                    keyboardType: TextInputType.number,
                    onSaved: (v) => poids = v,
                  ),
                if (!widget.googleFit)
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Taille (cm)'),
                    keyboardType: TextInputType.number,
                    onSaved: (v) => taille = v,
                  ),
                DropdownButtonFormField(
                  decoration: const InputDecoration(labelText: 'Sexe'),
                  items: ['Homme', 'Femme', 'Autre']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => sexe = v,
                ),
                const Divider(),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Email'),
                  onSaved: (v) => email = v,
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                  obscureText: true,
                  onSaved: (v) => password = v,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    _formKey.currentState?.save();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PreferencesFormPage()),
                    );
                  },
                  child: const Text('Suivant'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
