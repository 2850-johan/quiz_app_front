import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

// Importe les services et les pages de destination
import 'database_helper.dart'; 
import 'main.dart'; // Pour BACKEND_BASE_URL
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
    // Lance la séquence complète (Synchro puis Navigation)
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // 1. Attente minimum (pour l'effet visuel du splash)
    await Future.delayed(const Duration(milliseconds: 1500)); 

    // 2. Vérification de la connexion
    final connectivityResult = await (Connectivity().checkConnectivity());
    final bool isOnline = connectivityResult.contains(ConnectivityResult.mobile) ||
                          connectivityResult.contains(ConnectivityResult.wifi);
    
    final dbHelper = DatabaseHelper.instance; // Instance de la base de données locale
    final prefs = await SharedPreferences.getInstance(); // Instance de SharedPreferences

    // 3. Exécution de la synchronisation (SI EN LIGNE)
    if (isOnline) {
      print("Mode Online: Démarrage de la synchronisation...");
      try {
        // Tâche A: Envoyer les scores en attente au serveur  (Upload)
        await _syncPendingScores(dbHelper, prefs);
        
        // Tâche B: le telecharge pour le mettre en cache le classement (Download)
        await _cacheLeaderboard(dbHelper);

      } catch (e) {
        print("Erreur pendant la synchronisation au démarrage: $e");
        // On ne bloque pas l'utilisateur si la synchro échoue, on continue
      }
    } else {
      print("Mode Offline: Synchronisation ignorée.");
    }

    // 4. Logique de navigation (inchangée)
    if (!mounted) return;

    final token = prefs.getString('token');
    final userJson = prefs.getString('user');

    if (token != null && userJson != null) {
      // Utilisateur connecté
      final userData = jsonDecode(userJson);
      final userName = userData['nom'] ?? userData['email'] ?? 'Utilisateur';
      // Navigue vers l'écran de configuration du quiz si connecté
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => QuizSetupScreen(userName: userName)),
      );
    } else {
      // Navigue vers le local 
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }

  // --- Tâche A: Envoyer tout ce qui est  score au server  locaux vers MySQL ---
  Future<void> _syncPendingScores(DatabaseHelper dbHelper, SharedPreferences prefs) async {
    final token = prefs.getString('token');
    if (token == null) return; // Ne peut pas synchroniser sans token

    final pendingScores = await dbHelper.getPendingScores(); // Récupère les scores en attente en local
    if (pendingScores.isEmpty) {
      print("Synchro Upload: Aucun score en attente.");
      return;
    }

    print("Synchro Upload: ${pendingScores.length} score(s) à envoyer...");

    for (var score in pendingScores) {
      // Prépare le corps de la requête (sans l'ID local et la date)
      final body = {
        'level_label': score['level_label'],
        'theme': score['theme'],
        'score': score['score'],
        'total_questions': score['total_questions'],
      };

      try {
        final resp = await http.post(
          Uri.parse('$BACKEND_BASE_URL/score'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        );

        if (resp.statusCode == 201) {
          // Si succès, supprimer l'enregistrement local
          await dbHelper.deletePendingScore(score['id']);
          print("Score ${score['id']} synchronisé avec succès.");
        } else {
          print("Échec de la synchro pour le score ${score['id']} (Code: ${resp.statusCode})");
        }
      } catch (e) {
        print("Erreur réseau lors de la synchro du score ${score['id']}: $e");
        // On n'arrête pas la boucle, on essaiera au prochain démarrage
      }
    }
  }

  // --- Tâche B: DOWNLOAD (Mise en cache du classement MySQL vers SQFlite) ---
  Future<void> _cacheLeaderboard(DatabaseHelper dbHelper) async //Permet d'avoir le classement meme en local 
  {
    print("Synchro Download: Mise en cache du classement...");
    try {
      final resp = await http.get(Uri.parse('$BACKEND_BASE_URL/leaderboard')); // demande le classement au backend
      
      if (resp.statusCode == 200) {
        final leaderboardData = jsonDecode(resp.body) as List;
        
        // 1. Vider l'ancien cache
        await dbHelper.clearCachedLeaderboard();

        // 2. Remplir avec les nouvelles données + sauvegarde les entrées
        for (var entry in leaderboardData) {
          await dbHelper.insertCachedLeaderboardEntry(entry as Map<String, dynamic>);
        }
        print("Classement mis en cache avec ${leaderboardData.length} entrées.");
      } else {
        print("Échec de la mise en cache (Code: ${resp.statusCode})");
      }
    } catch (e) {
      print("Erreur réseau lors de la mise en cache: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    // Affiche le logo (assurez-vous d'avoir 'assets/images/quiz-logo.png')
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo (vous pouvez utiliser l'icône si l'asset n'est pas prêt)
            Image.asset(
              'assets/images/quiz-logo.png', 
              width: 150, 
              height: 150,
              errorBuilder: (context, error, stackTrace) {
                // Fallback si l'image n'est pas trouvée
                return Icon(Icons.quiz, size: 80, color: Colors.deepPurple);
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Quiz App', 
              style: TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              )
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }
}