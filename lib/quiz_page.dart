import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // 1. Import pour la connectivité

// Importe les pages et services
import 'main.dart'; 
import 'auth_page.dart'; 
import 'database_helper.dart'; // 2. Import de la base de données locale

// --- Définition des couleurs du nouveau Thème Vert (basé sur votre image) ---
const Color kThemeGreenLight = Color(0xFF1DE9B6); // Vert/Turquoise vif
const Color kThemeGreenDark = Color(0xFF00796B);  // Vert/Turquoise foncé

class QuizPage extends StatefulWidget {
  final String userName;
  final String level;
  final List<Map<String, dynamic>> questions;

  const QuizPage({
    super.key,
    required this.userName,
    required this.level,
    required this.questions,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> with TickerProviderStateMixin {
  
  // --- Variables du jeu ---
  int _index = 0;
  int _score = 0;
  int? _selected; 
  bool _showResult = false;
  List<Map<String, dynamic>> _wrongAnswers = []; 

  // --- Variables du Chronomètre ---
  final int _maxTime = 30; 
  late int _currentTime; 
  Timer? _timer;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _initTimerAndProgress();
  }
  
  void _initTimerAndProgress() {
    _currentTime = _maxTime;
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _maxTime),
    );
    _progressController.reverse(from: 1.0); 
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_currentTime > 0) {
            _currentTime--;
          } else {
            _timer?.cancel();
            _handleTimeout(); 
          }
        });
      }
    });
  }
  
  void _stopTimerAndReset() {
    _timer?.cancel();
    _progressController.stop();
  }
  
  void _handleTimeout() {
    _selected = null; 
    _next(); 
  }

  // ==========================================================
  // 🎯 LOGIQUE DE FIN DE QUIZ (PHASE 4)
  // ==========================================================

  void _next() {
    _stopTimerAndReset(); 
    
    final current = widget.questions[_index];
    final dynamic answerValue = current['answer']; 
    final int? correctIndex = answerValue is int 
        ? answerValue 
        : int.tryParse(answerValue.toString());
    
    if (correctIndex != null) {
      bool isCorrect = false;

      if (_selected != null) {
        if (_selected == correctIndex) {
          isCorrect = true;
          _score++;
        }
      } else {
        isCorrect = false;
      }
      
      if (!isCorrect) {
          _wrongAnswers.add({
              'index': _index,
              'question': current['question'],
              'choices': current['choices'],
              'correct_answer_index': correctIndex,
              'explanation': current['explanation'] ?? (_selected == null ? 'Temps écoulé.' : 'Non disponible'),
          });
      }
    } 

    // Progression ou fin du quiz
    if (_index < widget.questions.length - 1) {
      setState(() {
        _index++;
        _selected = null; 
        _initTimerAndProgress(); 
      });
    } else {
      // 1. Marquer le quiz comme terminé
      setState(() => _showResult = true);
      // 2. Lancer la sauvegarde du score (online ou offline)
      _submitScore(); 
    }
  }

  // 🎯 NOUVEAU: Fonction de sauvegarde (Online/Offline)
  Future<void> _submitScore() async {
    // 1. Préparer les données du score
    final scoreData = {
      'level_label': widget.level,
      'theme': "culture générale", // ⚠️ TODO: Remplacez par le vrai thème
      'score': _score,
      'total_questions': widget.questions.length,
    };

    // 2. Vérifier la connexion
    final connectivityResult = await (Connectivity().checkConnectivity());
    final bool isOnline = connectivityResult.contains(ConnectivityResult.mobile) ||
                          connectivityResult.contains(ConnectivityResult.wifi);
    
    if (isOnline) {
      // --- MODE EN LIGNE: Envoyer à MySQL ---
      print("Mode Online: Sauvegarde du score sur le serveur...");
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token'); 
        if (token == null) throw Exception("Token non trouvé");

        await http.post(
          Uri.parse('$BACKEND_BASE_URL/score'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token', 
          },
          body: jsonEncode(scoreData),
        );
        print("Score sauvegardé sur le serveur (MySQL).");
      } catch (e) {
        print("Erreur sauvegarde score (online), sauvegarde locale en fallback... $e");
        // Fallback: Si l'API échoue (ex: 503, timeout), on sauvegarde localement
        await _saveScoreLocally(scoreData);
      }
    } else {
      // --- MODE HORS LIGNE: Envoyer à SQFlite ---
      print("Mode Offline: Sauvegarde du score en local (SQFlite)...");
      await _saveScoreLocally(scoreData);
    }
  }

  // 🎯 NOUVEAU: Helper pour la sauvegarde locale
  Future<void> _saveScoreLocally(Map<String, dynamic> scoreData) async {
    // Ajoute la date pour la BDD locale
    scoreData['created_at'] = DateTime.now().toIso8601String();
    
    // Appelle le singleton de la base de données
    final dbHelper = DatabaseHelper.instance; 
    await dbHelper.insertPendingScore(scoreData);
    print("Score sauvegardé localement dans pending_scores.");
  }


  // ==========================================================
  // FONCTION DE DÉCONNEXION (Ajoutée pour le bouton de fin)
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

  @override
  void dispose() {
    _stopTimerAndReset();
    _progressController.dispose();
    super.dispose();
  }

  // --- WIDGET HELPER pour les cartes de résultat (inspiré de votre image) ---
  Widget _buildResultCard({required String title, required String value, required String subtitle}) {
    return Card(
      color: Colors.white.withOpacity(0.25), // Cartes translucides
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER pour les lignes de score ---
  Widget _buildScoreRow(String label, int value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Text(value.toString(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  // ==========================================================
  // 🎨 CONSTRUCTION DE L'INTERFACE
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    final int totalQuestions = widget.questions.length;
    final int incorrectScore = totalQuestions - _score;
    final int percentage = (totalQuestions > 0) ? ((_score / totalQuestions) * 100).round() : 0;
    
    // ==========================================================
    // 🏆 ÉCRAN DE RÉSULTATS (Nouveau Design Vert)
    // ==========================================================
    if (_showResult) {
        return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kThemeGreenDark, kThemeGreenLight],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: ListView( 
                  padding: const EdgeInsets.all(24.0),
                  children: [
                      // --- 1. En-tête ---
                      const SizedBox(height: 40),
                      const Icon(Icons.emoji_events, color: Colors.white, size: 80),
                      const SizedBox(height: 16),
                      Text(
                        'Quiz Terminé !',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Bravo ${widget.userName} ! Voici vos résultats',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      const SizedBox(height: 30),

                      // --- 2. Cartes de Score ---
                      _buildResultCard(
                        title: 'Score',
                        value: '$_score / $totalQuestions',
                        subtitle: '$percentage% de réussite',
                      ),
                      const SizedBox(height: 16),
                      _buildResultCard(
                        title: 'Réponses Correctes',
                        value: '$_score',
                        subtitle: 'Bien joué !',
                      ),
                      const SizedBox(height: 16),
                      _buildResultCard(
                        title: 'Réponses Incorrectes',
                        value: '$incorrectScore',
                        subtitle: 'À revoir',
                      ),

                      // --- 3. Détail des Erreurs (Liste de Révision) ---
                      if (_wrongAnswers.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          const Text('❌ Révision des Erreurs :', 
                               style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                          const Divider(height: 30, color: Colors.white54),

                          ..._wrongAnswers.map((error) {
                              final List choices = error['choices'] as List;
                              final int correct = error['correct_answer_index'] as int;

                              return Padding(
                                  padding: const EdgeInsets.only(bottom: 30),
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                          Text('Question #${error['index']! + 1}', 
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                          const SizedBox(height: 4),
                                          Text(error['question'], 
                                               style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.white)),
                                          const SizedBox(height: 8),
                                          
                                          Text('✅ Réponse Correcte: ${choices[correct]}', 
                                               style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                                          
                                          const SizedBox(height: 8),
                                          if (error['explanation'] != null && error['explanation']!.isNotEmpty)
                                              Text('💡 Explication: ${error['explanation']}', style: const TextStyle(fontSize: 14, color: Colors.white70)),
                                      ],
                                  ),
                              );
                          }).toList(),
                      ],
                      
                      // --- 4. Boutons Finaux (Recommencer et Déconnexion) ---
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          // Bouton Recommencer
                          Expanded(
                            child: ElevatedButton.icon(
                                onPressed: () => Navigator.pop(context), // Retourne au QuizSetupScreen
                                icon: const Icon(Icons.refresh, size: 24, color: kThemeGreenDark),
                                label: const Text('Recommencer', style: TextStyle(fontSize: 16, color: kThemeGreenDark)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white, 
                                  minimumSize: const Size.fromHeight(56),
                                ),
                            ),
                          ),
          
                          const SizedBox(width: 16), 
                          
                          // Bouton Déconnexion
                          Expanded(
                            child: ElevatedButton.icon( 
                                onPressed: _logout, // Appel de la fonction de déconnexion
                                icon: const Icon(Icons.logout, size: 24, color: Colors.white),
                                label: const Text('Quitter', style: TextStyle(fontSize: 16, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kThemeGreenDark.withOpacity(0.8),
                                  side: const BorderSide(color: Colors.white), // Bordure blanche
                                  minimumSize: const Size.fromHeight(56),
                                ),
                            ),
                          ),
                        ],
                      ),
                  ],
              ),
            ),
        );
    }
    
    // ==========================================================
    // ÉCRAN DE QUIZ PENDANT LE JEU
    // ==========================================================
    final q = widget.questions[_index];
    final List choices = q['choices'] as List;

    return Scaffold(
      appBar: AppBar(title: Text('Question ${_index + 1}/${widget.questions.length}')),
      body: SingleChildScrollView( 
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Chronomètre et Barre de Progression ---
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kThemeGreenLight), 
                    backgroundColor: Colors.grey[300],
                    value: _progressController.value, 
                    minHeight: 10,
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Temps restant : $_currentTime s',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kThemeGreenDark),
                ),
              ),
              
              const Divider(height: 20),
              Text(q['question'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ...List.generate(choices.length, (i) {
                return Card( 
                  color: _selected == i ? kThemeGreenLight.withOpacity(0.8) : Colors.white,
                  child: ListTile(
                    title: Text(choices[i].toString(), style: TextStyle(color: _selected == i ? Colors.black : Colors.black87)),
                    onTap: () => setState(() => _selected = i),
                    leading: CircleAvatar(
                      backgroundColor: _selected == i ? kThemeGreenDark : Colors.grey.shade200,
                      child: Text(String.fromCharCode(65 + i), style: TextStyle(color: _selected == i ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected == null ? null : _next,
                  child: Text(_index == widget.questions.length - 1 ? 'Terminer' : 'Suivant'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kThemeGreenDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}