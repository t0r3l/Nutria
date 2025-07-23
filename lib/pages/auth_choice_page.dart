import 'package:flutter/material.dart';
import 'login_page.dart';
import 'signup_method_page.dart';

class AuthChoicePage extends StatelessWidget {
  const AuthChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          /// Image de fond
          Image.asset(
            'assets/images/17.png',
            fit: BoxFit.cover,
          ),

          /// Contenu par-dessus
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text('Se connecter'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupMethodPage()),
                    );
                  },
                  child: const Text('S’inscrire'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
