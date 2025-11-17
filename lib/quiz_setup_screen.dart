import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Requis pour charger les assets JSON
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Requis pour la détection

// Importe les pages de destination
import 'main.dart'; 
import 'auth_page.dart'; 
import 'quiz_page.dart'; 
import 'leaderboard_tab.dart'; 

class QuizSetupScreen extends StatefulWidget {
  final String userName;
  const QuizSetupScreen({super.key, required this.userName});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  final GlobalKey<LeaderboardTabState> _leaderboardKey = GlobalKey<LeaderboardTabState>();

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
  // LOGIQUE DE PROGRESSION DES QUESTIONS
  // ==========================================================
  int _getQuestionCount() { 
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
  // FONCTION DE DÉCONNEXION
  // ==========================================================
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('userName');
    
    if (!mounted) return;
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthPage()), 
      (Route<dynamic> route) => false,
    );
  }

  // ==========================================================
  // 🚀 FONCTION DE DÉMARRAGE DU QUIZ (BIFURCATION ONLINE/OFFLINE)
  // ==========================================================
  Future<void> _startQuiz() async {
    setState(() { _loading = true; _error = null; });
    
    // 1. Détecter la connexion
    final connectivityResult = await (Connectivity().checkConnectivity());
    final bool isOnline = connectivityResult.contains(ConnectivityResult.mobile) ||
                          connectivityResult.contains(ConnectivityResult.wifi);

    List<Map<String, dynamic>> questions;

    try {
      if (isOnline) {
        // --- MODE EN LIGNE ---
        print("Mode Online: Appel de Mistral AI...");
        questions = await _fetchMistralQuiz();
      } else {
        // --- MODE HORS LIGNE ---
        print("Mode Offline: Chargement du JSON local...");
        questions = await _fetchLocalQuiz();
      }

      if (!mounted) return;

      // 5. Naviguer vers la page de jeu
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizPage(
            userName: widget.userName,
            level: _level,
            questions: questions,
          ),
        ),
      );

      // 6. Rafraîchir l'historique au retour
      _leaderboardKey.currentState?.refreshLeaderboard();

    } catch (e) {
      // Affiche l'erreur (soit de l'API, soit du chargement local)
      setState(() => _error = 'Erreur: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Helper: Logique EN LIGNE (Mistral AI) ---
  Future<List<Map<String, dynamic>>> _fetchMistralQuiz() async {
    final int questionCount = _getQuestionCount();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      await _logout();
      throw Exception("Session expirée. Reconnexion nécessaire.");
    }

    final resp = await http.post(
      Uri.parse('$BACKEND_BASE_URL/ai/quiz'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'theme': _themeCtrl.text.trim(),
        'level': _level,
        'count': questionCount,
      }),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return (data['questions'] as List).cast<Map<String, dynamic>>();
    } else if (resp.statusCode == 401 || resp.statusCode == 403) {
      await _logout();
      throw Exception("Session invalide. Reconnexion nécessaire.");
    } else {
      throw Exception("Erreur serveur (${resp.statusCode}): ${resp.body}");
    }
  }

  // --- Helper: Logique HORS LIGNE (JSON local) ---
  Future<List<Map<String, dynamic>>> _fetchLocalQuiz() async {
    // ⚠️ Note: Nous ignorons le thème et chargeons le quiz statique basé sur le niveau.
    
    // 1. Déterminer quel fichier charger (basé sur le niveau)
    String assetPath;
    switch (_level) {
      case 'facile':
        assetPath = 'assets/quiz/facile.json';
        break;
      case 'normal':
        assetPath = 'assets/quiz/normal.json';
        break;
      case 'intermediaire':
        assetPath = 'assets/quiz/intermediaire.json'; // 
        break;
      case 'difficile':
        assetPath = 'assets/quiz/difficile.json'; // 
        break;
      default:
        assetPath = 'assets/quiz/facile.json';
    }

    try {
      // 2. Charger le fichier JSON depuis les assets
      final String jsonString = await rootBundle.loadString(assetPath);
      final data = jsonDecode(jsonString);
      return (data['questions'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      // Gère le cas où le fichier (ex: difficile.json) n'a pas été créé
      print("Erreur lors du chargement du quiz local: $e");
      throw Exception("Le quiz hors ligne pour le niveau '$_level' n'a pas pu être chargé. Fichier '$assetPath' manquant ou corrompu.");
    }
  }


  // ==========================================================
  // CONSTRUCTION DE L'INTERFACE UTILISATEUR
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz App'),
        actions: [
          TextButton.icon(
            label: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      // Utilisation de DefaultTabController pour les onglets
      body: DefaultTabController(
        length: 2, 
        child: Column(
          children: [
            // Définition des onglets
            TabBar(
              labelColor: Theme.of(context).primaryColor, 
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(icon: Icon(Icons.quiz), text: 'Nouveau Quiz'),
                Tab(icon: Icon(Icons.history), text: 'Historique'),
              ],
            ),
            // Contenu des onglets
            Expanded(
              child: TabBarView(
                children: [
                  // Onglet 1: Le setup du quiz
                  SingleChildScrollView(
                    child: Padding(
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
                            isExpanded: true,
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
                          if (_error != null) 
                            Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          // Bouton de lancement
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _startQuiz,
                              child: Text(_loading ? 'Génération du quiz…' : 'Commencer le quiz'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Onglet 2: L'historique
                  LeaderboardTab(key: _leaderboardKey), 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}