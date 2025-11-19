// lib/main.dart (MODIFIÉ)
import 'package:flutter/material.dart';

// Importe le nouveau Splash Screen
import 'splash_screen.dart'; 

void main() => runApp(const MyApp());

// ⚠️ Votre constante d'URL de backend doit rester ici
// Si vous utilisez localtunnel (https://...), elle doit être mise à jour avant chaque session !
const String BACKEND_BASE_URL = 'http://10.150.228.26:3000'; 

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      // 🎯 L'application commence ici
      home: SplashScreen(), 
    );
  }
}
// Le reste des classes (AuthPage, QuizSetupScreen, QuizPage) doit être dans leurs propres fichiers !0*
