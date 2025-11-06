import 'package:flutter/material.dart';

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

class _QuizPageState extends State<QuizPage> {
  int _index = 0;
  int _score = 0;
  int? _selected; // index de la réponse choisie (0, 1, 2, ou 3)
  bool _showResult = false;
  
  // 🎯 Liste pour stocker les questions ratées et leurs détails
  List<Map<String, dynamic>> _wrongAnswers = []; 
// permet de verifier les reponses fausses et de les afficher a la fin du quiz
// chaque élément contient : index de la question, question, choix, bonne réponse, explication
  void _next() {
    // Si aucune réponse n'est sélectionnée, on ne peut pas avancer
    //FOnction de validation pour s'assurer qu'une réponse est choisie avant de continuer
    if (_selected == null) return; 

    final current = widget.questions[_index];
    
    // Récupération sécurisée de l'index correct (suppose que Mistral envoie un entier sous 'answer')
    final dynamic answerValue = current['answer']; 
    final int? correctIndex = answerValue is int 
        ? answerValue 
        : int.tryParse(answerValue.toString());
    
    if (correctIndex == null) {
        // En cas de donnée corrompue, on passe simplement à la suivante ou on gère l'erreur
        _index < widget.questions.length - 1 ? setState(() => _index++) : setState(() => _showResult = true);
        return; 
    }

    //  Logique de notation corrigée
    //Permet de vérifier si la réponse sélectionnée est correcte et de mettre à jour le score ou les erreurs
    if (_selected == correctIndex) {
      _score++;
    } else {
      // Si la réponse est FAUSSE, on enregistre les détails de l'erreur
      _wrongAnswers.add({
        'index': _index,
        'question': current['question'],
        'choices': current['choices'],
        'correct_answer_index': correctIndex,
        'explanation': current['explanation'] ?? 'Non disponible', // Utilise l'explication si Mistral l'a fournie
      });
    }

    // Progression ou fin du quiz
    if (_index < widget.questions.length - 1) {
      setState(() {
        _index++;
        _selected = null; // Réinitialise la sélection
      });
    } else {
      setState(() => _showResult = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ==========================================================
    // 🎯 ÉCRAN DE RÉSULTATS DÉTAILLÉ
    // ==========================================================
    if (_showResult) {
        return Scaffold(
            appBar: AppBar(title: const Text('Résultat du Quiz')),
            body: ListView( 
                padding: const EdgeInsets.all(16),
                children: [
                    // --- Résumé du Score ---
                    Text('Quiz terminé, ${widget.userName} ! 🎉', 
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('Score final : $_score / ${widget.questions.length}', 
                        style: TextStyle(fontSize: 18, color: _score >= widget.questions.length / 2 ? Colors.green : Colors.orange)),
                    const SizedBox(height: 20),
                    const Divider(),

                    // --- Liste des Questions Manquées ---
                    // 🎯 Affichage des questions ratées avec détails .
                    if (_wrongAnswers.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('❌ Questions Pas correcte (${_wrongAnswers.length}):', 
                             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(height: 10),

                        ..._wrongAnswers.map((error) {
                            final List choices = error['choices'] as List;
                            final int correct = error['correct_answer_index'] as int;

                            return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        Text('Question :${error['index']! + 1}', 
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Text(error['question'], 
                                             style: const TextStyle(fontStyle: FontStyle.italic)),
                                        const SizedBox(height: 8),

                                        // Affichage de la réponse Correcte
                                        // 🎯 Mise en évidence de la bonne réponse.
                                        Text('✅ Réponse Correcte: ${choices[correct]}', 
                                             style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 8),
                                        // Explication (si disponible)
                                        if (error['explanation'] != null && error['explanation']!.isNotEmpty)
                                            Text('💡 Explication: ${error['explanation']}', style: const TextStyle(fontSize: 13)),
                                    ],
                                ),
                            );
                        }).toList(),
                        const Divider(),
                    ],
                    
                    // --- Bouton de Retour ---
                    const SizedBox(height: 16),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Retour à la Configuration'),
                        ),
                    ),
                ],
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q['question'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...List.generate(choices.length, (i) {
              return ListTile(
                title: Text(choices[i].toString()),
                leading: Radio<int>(
                  value: i,
                  groupValue: _selected,
                  onChanged: (v) => setState(() => _selected = v),
                ),
              );
            }),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected == null ? null : _next,
                child: Text(_index == widget.questions.length - 1 ? 'Terminer' : 'Suivant'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}