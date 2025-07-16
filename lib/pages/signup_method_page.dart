import 'package:flutter/material.dart';
import 'signup_form_page.dart';

class SignupMethodPage extends StatelessWidget {
  const SignupMethodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Méthode d’inscription')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupFormPage(googleFit: false)),
                );
              },
              child: const Text('S’inscrire manuellement'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupFormPage(googleFit: true)),
                );
              },
              child: const Text('S’inscrire avec Google Fit'),
            ),
          ],
        ),
      ),
    );
  }
}
