import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_api/amplify_api.dart';
import 'amplifyconfiguration.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const NutriaApp());
}

class NutriaApp extends StatefulWidget {
  const NutriaApp({super.key});

  @override
  State<NutriaApp> createState() => _NutriaAppState();
}

class _NutriaAppState extends State<NutriaApp> {
  bool _amplifyConfigured = false;

  @override
  void initState() {
    super.initState();
    _configureAmplify();
  }

  Future<void> _configureAmplify() async {
    try {
      // Add Amplify plugins
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.addPlugin(AmplifyAPI());

      // Configure Amplify
      await Amplify.configure(amplifyconfig);

      setState(() {
        _amplifyConfigured = true;
      });

      safePrint('Successfully configured Amplify');
    } on Exception catch (e) {
      safePrint('Error configuring Amplify: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutria - Google Fit Integration',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: _amplifyConfigured
          ? const HomeScreen()
          : const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}