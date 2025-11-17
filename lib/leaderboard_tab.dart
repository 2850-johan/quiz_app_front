import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart'; // 1. Import pour la connectivité

// Importe les services et pages
import 'main.dart'; 
import 'database_helper.dart'; // 2. Import de la base de données locale

const Color kThemeGreenDark = Color(0xFF00796B); 

// Widget pour l'onglet Classement
class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key});

  @override
  State<LeaderboardTab> createState() => LeaderboardTabState();
}

class LeaderboardTabState extends State<LeaderboardTab> {
  late Future<List<dynamic>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = _fetchLeaderboard();
  }

  // ==========================================================
  // 🎯 LOGIQUE DE LECTURE (ONLINE/OFFLINE)
  // ==========================================================
  Future<List<dynamic>> _fetchLeaderboard() async {
    // 1. Vérifier la connexion
    final connectivityResult = await (Connectivity().checkConnectivity());
    final bool isOnline = connectivityResult.contains(ConnectivityResult.mobile) ||
                          connectivityResult.contains(ConnectivityResult.wifi);
    
    final dbHelper = DatabaseHelper.instance;

    if (isOnline) {
      // --- MODE EN LIGNE ---
      print("Leaderboard: Mode Online - Lecture depuis le serveur (MySQL)...");
      try {
        final response = await http.get(Uri.parse('$BACKEND_BASE_URL/leaderboard')); 
        
        if (response.statusCode == 200) {
          final leaderboardData = jsonDecode(response.body) as List<dynamic>;
          
          // 2. Mettre à jour le cache local en arrière-plan
          await dbHelper.clearCachedLeaderboard();
          for (var entry in leaderboardData) {
            await dbHelper.insertCachedLeaderboardEntry(entry as Map<String, dynamic>);
          }
          
          return leaderboardData;
        } else {
          // Si le serveur a une erreur, on lit le cache
          print("Leaderboard: Erreur serveur, lecture du cache en fallback...");
          return await dbHelper.getCachedLeaderboard();
        }
      } catch (e) {
        // Si le réseau plante (timeout), on lit le cache
        print("Leaderboard: Erreur réseau, lecture du cache en fallback... $e");
        return await dbHelper.getCachedLeaderboard();
      }
    } else {
      // --- MODE HORS LIGNE ---
      print("Leaderboard: Mode Offline - Lecture depuis le cache (SQFlite)...");
      return await dbHelper.getCachedLeaderboard();
    }
  }

  // Fonction publique pour forcer le rafraîchissement
  Future<void> refreshLeaderboard() async {
    setState(() {
      _leaderboardFuture = _fetchLeaderboard();
    });
  }
  
  // (Le reste du code (helpers et build) est inchangé)

  // Fonction helper pour l'icône de rang
  Widget _getRankIcon(int rank) {
    switch (rank) {
      case 1:
        return Icon(Icons.emoji_events, color: Colors.yellow.shade700, size: 30); // Trophy
      case 2:
        return Icon(Icons.military_tech, color: Colors.grey.shade500, size: 30); // Medal
      case 3:
        return Icon(Icons.workspace_premium, color: Colors.brown.shade700, size: 30); // Award
      default:
        return Text(
          '#$rank',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
        );
    }
  }
  
  // Fonction helper pour l'avatar
  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    List<String> parts = name.split(' ');
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return parts[0][0].toUpperCase() + parts[1][0].toUpperCase();
    }
    return parts[0].length > 1 ? parts[0].substring(0, 2).toUpperCase() : parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: RefreshIndicator(
        onRefresh: refreshLeaderboard, 
        color: kThemeGreenDark, 
        child: FutureBuilder<List<dynamic>>(
          future: _leaderboardFuture,
          builder: (context, snapshot) {
            
            // Cas 1: Chargement
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: kThemeGreenDark));
            }
            
            // Cas 2: Erreur
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Erreur: ${snapshot.error}'),
                )
              );
            }
            
            // Cas 3: Données vides
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Aucun score trouvé (en ligne ou en cache).'));
            }

            // Cas 4: Succès
            final leaderboard = snapshot.data!;
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: leaderboard.length + 1, // +1 pour la carte d'en-tête
              itemBuilder: (context, index) {
                
                // --- Carte d'en-tête ---
                if (index == 0) {
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Icon(Icons.leaderboard, size: 40, color: kThemeGreenDark),
                          SizedBox(height: 8),
                          Text(
                            'Classement Global',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kThemeGreenDark),
                          ),
                          Text('Les meilleurs scores de tous les joueurs'),
                        ],
                      ),
                    ),
                  );
                }
                
                // --- Lignes du classement ---
                final entry = leaderboard[index - 1]; 

                return Card(
                  margin: const EdgeInsets.only(top: 12),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Rang
                        SizedBox(width: 40, child: Center(child: _getRankIcon(entry['rank']))),
                        const SizedBox(width: 12),
                        
                        // Avatar
                        CircleAvatar(
                          backgroundColor: kThemeGreenDark,
                          child: Text(_getInitials(entry['user_nom'] ?? 'N/A'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        
                        // Nom et Niveau
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry['user_nom'] ?? 'N/A',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text('Niveau: ${entry['level'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                        
                        // Score Total
                        Text(
                          '${entry['best_score']}/${entry['total_questions']}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kThemeGreenDark),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}