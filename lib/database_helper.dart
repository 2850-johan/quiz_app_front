import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseHelper {
  // Nom de la base de données
  static const _databaseName = "QuizAppOffline.db";
  static const _databaseVersion = 1;

  // Noms des tables pour les scores en attente et le classement en cache
  static const tablePendingScores = 'pending_scores';
  static const tableCachedLeaderboard = 'cached_leaderboard';

  // --- Singleton (Instance unique) ---
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialisation de la base de données
  _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);// chemin complet de la base de donnees localement
    return await openDatabase(path,
        version: _databaseVersion,
        onCreate: _onCreate);
  }

  // --- Création des tables ---
  Future _onCreate(Database db, int version) async {
    
    // Table pour les scores faits hors ligne (en attente d'envoi)
    await db.execute('''
      CREATE TABLE $tablePendingScores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        level_label TEXT NOT NULL,
        theme TEXT NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        created_at TEXT NOT NULL 
      )
    ''');

    // Table pour le classement (cache téléchargé)
    await db.execute('''
      CREATE TABLE $tableCachedLeaderboard (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rank INTEGER NOT NULL,
        user_nom TEXT NOT NULL,
        level TEXT NOT NULL,
        best_score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL
      )
    ''');
  }

  // ==========================================================
  // MÉTHODES POUR LES SCORES EN ATTENTE (PENDING SCORES)
  // ==========================================================

  // Insérer un score en attente (quand hors ligne)
  Future<int> insertPendingScore(Map<String, dynamic> row) async {
    Database db = await instance.database;
    return await db.insert(tablePendingScores, row);
  }

  // Récupérer tous les scores en attente
  Future<List<Map<String, dynamic>>> getPendingScores() async {
    Database db = await instance.database;
    return await db.query(tablePendingScores);
  }

  // Supprimer un score en attente (après l'avoir envoyé à MySQL)
  Future<int> deletePendingScore(int id) async {
    Database db = await instance.database;
    return await db.delete(tablePendingScores, where: 'id = ?', whereArgs: [id]);
  }

  // (Optionnel: Vider tous les scores en attente)
  Future<int> clearPendingScores() async {
    Database db = await instance.database;
    return await db.delete(tablePendingScores);
  }
  
  // ==========================================================
  // MÉTHODES POUR LE CLASSEMENT EN CACHE (CACHED LEADERBOARD)
  // ==========================================================
  
  // Vider l'ancien cache
  Future<void> clearCachedLeaderboard() async {
    Database db = await instance.database;
    await db.delete(tableCachedLeaderboard);
  }

  // Insérer le nouveau classement (téléchargé depuis MySQL)
  Future<void> insertCachedLeaderboardEntry(Map<String, dynamic> entry) async {
    Database db = await instance.database;
    // On retire 'rank' si le backend l'a ajouté, car la BDD locale a son propre ID
    // (Note: La requête leaderboard de index.js renvoie 'rank')
    await db.insert(tableCachedLeaderboard, entry);
  }

  // Récupérer le classement en cache (quand hors ligne)
  Future<List<Map<String, dynamic>>> getCachedLeaderboard() async {
    Database db = await instance.database;
    return await db.query(tableCachedLeaderboard, orderBy: 'rank ASC');
  }
}