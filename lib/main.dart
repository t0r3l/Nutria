import 'package:flutter/material.dart';
import 'pages/welcome_page.dart';

void main() {
  runApp(const NutriaApp());
}

class NutriaApp extends StatelessWidget {
  const NutriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nutria',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const WelcomePage(),
    );
  }
}
