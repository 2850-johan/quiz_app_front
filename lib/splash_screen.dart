import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importe les pages de destination
import 'auth_page.dart'; 
import 'quiz_setup_screen.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  
  @override
  void initState() {
    super.initState();
    // Lance la vérification après un court délai pour montrer le Splash Screen
    _checkAuthAndNavigate();
  }

  // --- LOGIQUE DE VÉRIFICATION DU JETON ---
  Future<void> _checkAuthAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userJson = prefs.getString('user');
    
    // Simuler un temps de chargement minimum de 1.5 seconde
    await Future.delayed(const Duration(milliseconds: 1500)); 

    if (!mounted) return;

    if (token != null && userJson != null) {
      // 1. Jeton et utilisateur trouvés : Rediriger vers l'écran de configuration du quiz
      final userData = jsonDecode(userJson);
      final userName = userData['nom'] ?? userData['email'] ?? 'Utilisateur';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => QuizSetupScreen(userName: userName)),
      );
    } else {
      // 2. Jeton manquant : Rediriger vers l'écran de connexion
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 Design simple du Splash Screen
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //  (Imaginez ici votre logo ou une icône)
            Icon(Icons.quiz, size: 80, color: Colors.deepPurple), 
            SizedBox(height: 20),
            Text('Quiz Master Pro', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }
}