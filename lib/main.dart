import 'package:flutter/material.dart';
// Importe la page où commence l'authentification
import 'auth_page.dart'; 

void main() => runApp(const MyApp());

// ⚠️ IMPORTANT : L'IP de votre machine (PC) sur le réseau partagé par votre téléphone
// Dans main.dart
const String BACKEND_BASE_URL = 'http://172.16.81.203:3000'; //   10.26.114.26

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthPage(),
    );
  }
}