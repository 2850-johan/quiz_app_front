import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Importe la constante d'URL et la page de destination
import 'main.dart'; 
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

  Future<void> _startQuiz() async {
    setState(() { _loading = true; _error = null; });
    
    // ⚠️ Rappel : /ai/quiz DOIT être implémenté dans votre index.js (appel Mistral)
    try {
      final resp = await http.post(
        Uri.parse('$BACKEND_BASE_URL/ai/quiz'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'theme': _themeCtrl.text.trim(),
          'level': _level,
          'count': 5, // nombre de questions
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        // On suppose que le backend retourne une liste de questions sous la clé 'questions'
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
      appBar: AppBar(title: const Text('Quiz App')),
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