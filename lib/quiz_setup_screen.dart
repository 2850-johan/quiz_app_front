import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // Ajouté pour la déconnexion si besoin

// Importe la constante d'URL et la page de destination
import 'main.dart'; 
import 'auth_page.dart'; // Ajouté pour la déconnexion
import 'quiz_page.dart'; 

class QuizSetupScreen extends StatefulWidget {
  final String userName;
  const QuizSetupScreen({super.key, required this.userName});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  final _themeCtrl = TextEditingController(text: 'culture générale');
  final _levels = const ['facile', 'normal', 'intermediaire', 'difficile'];
  String _level = 'facile';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _themeCtrl.dispose();
    super.dispose();
  }

  // ==========================================================
  //  LOGIQUE DE PROGRESSION DES QUESTIONS
  // ==========================================================
  int _getQuestionCount() {// fonction qui permet de déterminer le nombre de questions par niveau choisis par l'utilisateur
  
    int levelIndex; 
    
    switch (_level) {
      case 'facile': levelIndex = 1; break;
      case 'normal': levelIndex = 2; break;
      case 'intermediaire': levelIndex = 3; break;
      case 'difficile': levelIndex = 4; break;
      default: levelIndex = 1; 
    }
    
    return 5 * levelIndex; 
  }
  
  // ==========================================================
  // FONCTION DE DÉCONNEXION (Ajoutée pour l'UX)
  // ==========================================================
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('userName');
    
    if (!mounted) return;
    
    // Retourne à la page de connexion (AuthPage) et vide l'historique
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthPage()), 
      (Route<dynamic> route) => false,
    );
  }


  Future<void> _startQuiz() async {
    setState(() { _loading = true; _error = null; });
    
    // Récupération dynamique du nombre de questions
    final int questionCount = _getQuestionCount();

    try {
      final resp = await http.post(
        Uri.parse('$BACKEND_BASE_URL/ai/quiz'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'theme': _themeCtrl.text.trim(),
          'level': _level,
          'count': questionCount, // ⬅️ Envoi de la valeur dynamique
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final questions = (data['questions'] as List).cast<Map<String, dynamic>>(); 

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuizPage(
              userName: widget.userName,
              level: _level,
              questions: questions,
            ),
          ),
        );
      } else {
        setState(() => _error = 'Erreur serveur (${resp.statusCode}): ${resp.body}');
      }
    } catch (e) {
      setState(() => _error = 'Erreur réseau/génération : ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz App'),
        // Ajout du bouton de déconnexion
        actions: [
          TextButton.icon(
            label: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bienvenue ${widget.userName} 👋', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Choisis ton niveau :'),
            const SizedBox(height: 8),
            // Sélecteur de niveau
            DropdownButton<String>(
              value: _level,
              items: _levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (v) => setState(() => _level = v!),
            ),
            const SizedBox(height: 16),
            const Text('Thème du quiz :'),
            const SizedBox(height: 8),
            // Champ pour le thème
            TextField(
              controller: _themeCtrl,
              decoration: const InputDecoration(
                hintText: 'ex: géographie, maths, histoire…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            // Bouton de lancement
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _startQuiz,
                child: Text(_loading ? 'Génération du quiz…' : 'Commencer le quiz'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}