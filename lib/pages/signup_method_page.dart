import 'package:flutter/material.dart';
import 'signup_form_page.dart';

class SignupMethodPage extends StatelessWidget {
  const SignupMethodPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SignupFormPage(googleFit: false),
              ),
            );
          },
          child: const Text('S’inscrire'),
        ),
      ),
    );
  }
}
