import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Importe la constante d'URL et la page de destination
import 'main.dart'; 
import 'quiz_setup_screen.dart'; 

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _status = 'Prêt';

  final _gsi = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '42999153219-hf44a5a23qssek59vd2qp227g6he9862.apps.googleusercontent.com',//id de client OAuth 2.0 pour les applications Web
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // Fonction de navigation commune après succès
  void _onLoginSuccess(Map<String, dynamic> user, BuildContext context) {
    final userName = user['nom'] ?? user['email'] ?? 'Utilisateur';
    
    if (!mounted) return;
    
    // Navigue vers la page de setup du quiz
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizSetupScreen(userName: userName),
      ),
    );
  }

  // ---------- Connexion classique Nom + Email ----------
  Future<void> _loginBasic() async {
    final nom = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    
    // ... (Votre logique de validation et de connexion HTTP) ...
    if (nom.isEmpty || email.isEmpty) {
      setState(() => _status = 'Veuillez saisir nom et email.');
      return;
    }
    final emailOk = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);//hachage simple de validation d'email
    if (!emailOk) {
      setState(() => _status = 'Email invalide.');
      return;
    }

    try {
      setState(() => _status = 'Connexion en cours…');
      final res = await http.post(
        Uri.parse('$BACKEND_BASE_URL/auth/basic'), 
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'nom': nom, 'email': email}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['accessToken'];
        final user = data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('user', jsonEncode(user));
        
        _onLoginSuccess(user, context);

      } else {
        setState(() => _status = '❌ Erreur serveur: ${res.body}');
      }
    } catch (e) {
      setState(() => _status = 'Erreur de connexion (Basic): $e');
    }
  }

  // ---------- Connexion Google ----------
  Future<void> _loginGoogle() async {
    try {
      setState(() => _status = 'Connexion Google…');
      final account = await _gsi.signIn();
      if (account == null) {
        setState(() => _status = 'Connexion annulée');
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        setState(() => _status = 'idToken Google nul.');
        return;
      }

      final res = await http.post(
        Uri.parse('$BACKEND_BASE_URL/auth/google'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
// 
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['accessToken'];
        final user = data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('user', jsonEncode(user));
        
        _onLoginSuccess(user, context);

      } else {
        setState(() => _status = '❌ Erreur serveur: ${res.body}');
      }
    } catch (e) {
      setState(() => _status = 'Erreur de connexion (Google): $e');
    }
  }

  Future<void> _logoutGoogle() async {
    await _gsi.signOut();
    setState(() => _status = 'Déconnecté (Google).');
  }

  // ---------- Construction de l'UI de connexion ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz App ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Bloc Email ---
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Connexion email', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            // Champ Nom
            TextField( 
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 8),
            // Champ Email
            TextField( 
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            // Bouton de connexion Nom + Email
            ElevatedButton(onPressed: _loginBasic, child: const Text('Continuer')),

            const Divider(height: 32),

            // --- Bloc Google ---
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Ou', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            // Bouton de connexion Google
            ElevatedButton(onPressed: _loginGoogle, child: const Text('Se connecter avec Google')),
            TextButton(onPressed: _logoutGoogle, child: const Text('Se déconnecter (Google)')),

            const SizedBox(height: 16),
            Text(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}