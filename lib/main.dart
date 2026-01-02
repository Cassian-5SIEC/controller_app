import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'robot_provider.dart';
import 'control_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    // Initialisation du Provider au sommet de l'arbre des widgets
    ChangeNotifierProvider(
      create: (context) => RobotProvider()..loadSettings(),
      child: const MyApp(),
    ),
  );
}

// La classe MyApp doit être définie ici
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robot Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      // On définit ControlScreen comme écran d'accueil
      home: const ControlScreen(),
    );
  }
}
