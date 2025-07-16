import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();

  String nom = 'Diop';
  String prenom = 'Maty';
  int age = 22;
  double poids = 70;
  double taille = 170;
  String sexe = 'Femme';
  String objectif = 'Santé générale';
  String activite = 'Sédentaire';
  double poidsCible = 65;

  int petitDejPct = 30;
  int dejeunerPct = 40;
  int dinerPct = 30;

  final List<Map<String, dynamic>> historiquePoids = [];

  void enregistrerProfil() {
    final now = DateTime.now().toIso8601String().substring(0, 10);
    historiquePoids.add({"date": now, "poids": poids});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil mis à jour ✨')),
    );
    // TODO: Envoyer profil + historiquePoids au backend
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('👤 Mon Profil')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          /// 📷 Fond d’écran
          Image.asset(
            'assets/images/18.png', // 🔷 Mets le nom de ton image ici
            fit: BoxFit.cover,
          ),

          /// 📄 Contenu du formulaire
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informations personnelles',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: nom,
                          decoration: const InputDecoration(labelText: 'Nom'),
                          onChanged: (val) => nom = val,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: prenom,
                          decoration: const InputDecoration(labelText: 'Prénom'),
                          onChanged: (val) => prenom = val,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: age.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Âge'),
                          onChanged: (val) => age = int.tryParse(val) ?? age,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: sexe,
                          items: ['Homme', 'Femme'].map((s) {
                            return DropdownMenuItem(value: s, child: Text(s));
                          }).toList(),
                          decoration: const InputDecoration(labelText: 'Sexe'),
                          onChanged: (val) => setState(() => sexe = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Mensurations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: poids.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Poids actuel (kg)'),
                          onChanged: (val) => poids = double.tryParse(val) ?? poids,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: poidsCible.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Poids cible (kg)'),
                          onChanged: (val) => poidsCible = double.tryParse(val) ?? poidsCible,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    initialValue: taille.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Taille (cm)'),
                    onChanged: (val) => taille = double.tryParse(val) ?? taille,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Objectifs & activité',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField(
                    value: objectif,
                    decoration: const InputDecoration(labelText: 'Objectif'),
                    items: [
                      'Perte de poids',
                      'Maintien',
                      'Prise de muscle',
                      'Santé générale',
                      'Bien-être'
                    ].map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => objectif = val!),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField(
                    value: activite,
                    decoration: const InputDecoration(labelText: 'Activité physique'),
                    items: [
                      'Sédentaire',
                      'Légèrement actif',
                      'Actif',
                      'Très actif'
                    ].map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => activite = val!),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Répartition des repas (%)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    initialValue: petitDejPct.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Petit déjeuner (%)'),
                    onChanged: (val) => petitDejPct = int.tryParse(val) ?? petitDejPct,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    initialValue: dejeunerPct.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Déjeuner (%)'),
                    onChanged: (val) => dejeunerPct = int.tryParse(val) ?? dejeunerPct,
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    initialValue: dinerPct.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Dîner (%)'),
                    onChanged: (val) => dinerPct = int.tryParse(val) ?? dinerPct,
                  ),

                  const SizedBox(height: 30),

                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer les modifications'),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          enregistrerProfil();
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (historiquePoids.isNotEmpty) ...[
                    const Text(
                      'Historique des poids',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: historiquePoids.map((e) {
                        return ListTile(
                          title: Text('${e['poids']} kg'),
                          subtitle: Text('Date : ${e['date']}'),
                          leading: const Icon(Icons.monitor_weight),
                        );
                      }).toList(),
                    )
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
