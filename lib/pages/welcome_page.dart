import 'package:flutter/material.dart';
import 'auth_choice_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          /// Image de fond
          Image.asset(
            'assets/images/20.png',
            fit: BoxFit.cover,
          ),

          /// Contenu par-dessus
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthChoicePage()),
                );
              },
              child: const Text('Commencer'),
            ),
          ),
        ],
      ),
    );
  }
}
