import 'package:flutter/material.dart';
import 'dashboard_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Se connecter')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
            },
            child: const Text('Connexion'),
          ),
        ),
      ),
    );
  }
}
