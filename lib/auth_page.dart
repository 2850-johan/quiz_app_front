import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Pour les icônes

// Importe les pages de destination et la constante d'URL
import 'main.dart'; 
import 'quiz_setup_screen.dart'; 

// --- Constantes de Couleur pour le Thème ---
const Color kCyan500 = Color(0xFF00BCD4);
const Color kTeal500 = Color(0xFF009688);
const Color kEmerald500 = Color(0xFF4CAF50);
const Color kTeal600 = Color(0xFF00897B);

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _status = 'Prêt';

  final _gsi = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '42999153219-hf44a5a23qssek59vd2qp227g6he9862.apps.googleusercontent.com',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Fonction de navigation commune après succès
  void _onLoginSuccess(Map<String, dynamic> user, BuildContext context) {
    final userName = user['nom'] ?? user['email'] ?? 'Utilisateur';
    
    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizSetupScreen(userName: userName),
      ),
    );
  }

  // ---------- LOGIQUE CONNEXION BASIQUE (Nom + Email) ----------
  Future<void> _loginBasic() async {
    final nom = _nameController.text.trim();
    final email = _emailController.text.trim();
    
    if (nom.isEmpty || email.isEmpty) {
      setState(() => _status = 'Veuillez saisir nom et email.');
      return;
    }
    final emailOk = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
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
        final user = data['user'];
        // Sauvegarde de la session
        await SharedPreferences.getInstance().then((prefs) {
          prefs.setString('token', data['accessToken']);
          prefs.setString('user', jsonEncode(user));
        });
        _onLoginSuccess(user, context);
      } else {
        setState(() => _status = '❌ Erreur serveur: ${res.body}');
      }
    } catch (e) {
      setState(() => _status = 'Erreur de connexion (Basic): $e');
    }
  }

  // ---------- LOGIQUE CONNEXION GOOGLE ----------
  Future<void> _loginGoogle() async {
    try {
      setState(() => _status = 'Connexion Google…');
      final account = await _gsi.signIn();
      if (account == null) {
        setState(() => _status = 'Connexion annulée');
        return;
      }
      final auth = await account.authentication;
      final res = await http.post(
        Uri.parse('$BACKEND_BASE_URL/auth/google'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'idToken': auth.idToken}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final user = data['user'];
        // Sauvegarde de la session
        await SharedPreferences.getInstance().then((prefs) {
          prefs.setString('token', data['accessToken']);
          prefs.setString('user', jsonEncode(user));
        });
        _onLoginSuccess(user, context);
      } else {
        setState(() => _status = '❌ Erreur serveur: ${res.body}');
      }
    } catch (e) {
      setState(() => _status = 'Erreur de connexion (Google): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. Arrière-plan en Dégradé
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kCyan500, kTeal500, kEmerald500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        // 2. Centrage du contenu et défilement
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- En-tête (Branding QuizMaster) ---
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.star, size: 40, color: kTeal600),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'QuizMaster',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Testez vos connaissances !',
                          style: TextStyle(color: Color(0xFFB2DFDB)),
                        ),
                      ],
                    ),
                  ),

                  // --- Carte de Connexion ---
                  Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Connexion', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Choisissez votre méthode de connexion', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 24),

                          // 1. Bouton Google
                          ElevatedButton.icon(
                            onPressed: _loginGoogle, // ⬅️ Appel à la logique Google
                            icon: const FaIcon(FontAwesomeIcons.google, size: 20, color: Colors.black54),
                            label: const Text('Continuer avec Google', style: TextStyle(fontSize: 18)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              minimumSize: const Size.fromHeight(56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Séparateur
                          Row(
                            children: [
                              const Expanded(child: Divider(color: Colors.grey, thickness: 1)),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('Ou continuer avec', style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                              const Expanded(child: Divider(color: Colors.grey, thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 2. Formulaire Email/Nom
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nom complet', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(hintText: 'Jean Dupont', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                              ),
                              const SizedBox(height: 16),

                              const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(hintText: 'jean.dupont@example.com', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                              ),
                              const SizedBox(height: 24),

                              // Bouton Se connecter
                              ElevatedButton.icon(
                                onPressed: _loginBasic, // ⬅️ Appel à la logique Basique
                                icon: const FaIcon(FontAwesomeIcons.envelope, size: 20, color: Colors.white),
                                label: const Text('Se connecter', style: TextStyle(fontSize: 18)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor, // Utilise la couleur principale du thème
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(56),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Affichage du statut (erreur ou prêt)
                          Text(_status, style: TextStyle(color: _status.startsWith('❌') ? Colors.red : Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                  ),

                  // --- Mentions Légales ---
                  const SizedBox(height: 16),
                  const Text('En vous connectant, vous acceptez nos conditions d\'utilisation', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFB2DFDB), fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}