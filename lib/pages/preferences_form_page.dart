import 'package:flutter/material.dart';
import 'dashboard_page.dart';

class PreferencesFormPage extends StatefulWidget {
  const PreferencesFormPage({super.key});

  @override
  State<PreferencesFormPage> createState() => _PreferencesFormPageState();
}

class _PreferencesFormPageState extends State<PreferencesFormPage> {
  final Set<String> allergies = {};
  final Set<String> alimentsAEviter = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Objectifs & Préférences')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField(
              decoration: const InputDecoration(labelText: 'Objectif'),
              items: [
                'Perte de poids', 'Maintien', 'Prise de muscle',
                'Santé générale', 'Bien-être'
              ].map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField(
              decoration: const InputDecoration(labelText: 'Activité physique'),
              items: [
                'Sédentaire', 'Légèrement actif', 'Actif', 'Très actif'
              ].map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField(
              decoration: const InputDecoration(labelText: 'Régime'),
              items: [
                'Omnivore', 'Végétarien', 'Végétalien', 'Pescetarien',
                'Flexitarien', 'Sans porc', 'Casher', 'Halal', 'Autre'
              ].map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 10),

            TextFormField(
              decoration: const InputDecoration(labelText: 'Autre (si régime Autre)'),
            ),

            const SizedBox(height: 20),
            const Divider(),

            const Text('Allergies & Intolérances', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                'Gluten', 'Lactose', 'Fruits à coque', 'Œufs', 'Soja', 'Crustacés'
              ].map((e) => FilterChip(
                label: Text(e),
                selected: allergies.contains(e),
                onSelected: (val) {
                  setState(() {
                    val ? allergies.add(e) : allergies.remove(e);
                  });
                },
              )).toList(),
            ),

            const SizedBox(height: 20),
            const Divider(),

            const Text('Aliments à éviter', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                'Porc', 'Bœuf', 'Crustacés', 'Alcool'
              ].map((e) => FilterChip(
                label: Text(e),
                selected: alimentsAEviter.contains(e),
                onSelected: (val) {
                  setState(() {
                    val ? alimentsAEviter.add(e) : alimentsAEviter.remove(e);
                  });
                },
              )).toList(),
            ),

            const SizedBox(height: 20),
            const Divider(),

            const Text('Répartition des repas (%)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Petit déjeuner (%)'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Déjeuner (%)'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Dîner (%)'),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Collation (%)'),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  print('Allergies: $allergies');
                  print('Aliments à éviter: $alimentsAEviter');
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const DashboardPage()),
                        (route) => false,
                  );
                },
                child: const Text('Terminer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
