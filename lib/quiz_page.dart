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

  void _next() {
    if (_selected == null) return;

    final current = widget.questions[_index];
    
    // ⚠️ IMPORTANT : Assurez-vous que le backend renvoie l'index de la bonne réponse sous 'answer'.
    // Si Mistral renvoie le texte de la réponse, vous devrez convertir le texte en index ici.
    final correctIndex = current['answer'] as int; 

    if (_selected == correctIndex) _score++;

    if (_index < widget.questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
      });
    } else {
      setState(() => _showResult = true);
      // OPTIONNEL : Envoyer le score au backend
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return Scaffold(
        appBar: AppBar(title: const Text('Résultat')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Bravo ${widget.userName} 🎉', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Score: $_score / ${widget.questions.length} (niveau: ${widget.level})'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Revenir'),
              ),
            ],
          ),
        ),
      );
    }

    final q = widget.questions[_index];
    final List choices = q['choices'] as List; // Options de réponse

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