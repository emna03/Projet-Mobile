import 'package:flutter/material.dart';

import '../models/question.dart';
import '../models/quiz.dart';
import '../theme/quiz_theme.dart';
import '../viewmodels/quiz_viewmodel.dart';
import '../widgets/difficulty_chip.dart';
import 'quiz_detail_page.dart';

class QuizCreatePage extends StatefulWidget {
  const QuizCreatePage({super.key, this.quiz});

  final Quiz? quiz;

  @override
  State<QuizCreatePage> createState() => _QuizCreatePageState();
}

class _DraftQuestion {
  _DraftQuestion()
      : text = TextEditingController(),
        options = List<TextEditingController>.generate(4, (_) => TextEditingController());

  _DraftQuestion.fromQuestion(Question question)
      : text = TextEditingController(text: question.text),
        options = [
          for (var i = 0; i < 4; i++)
            TextEditingController(text: i < question.options.length ? question.options[i] : ''),
        ],
        correctIndex = question.correctIndex;

  final TextEditingController text;
  final List<TextEditingController> options;
  int correctIndex = 0;

  void dispose() {
    text.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class _QuizCreatePageState extends State<QuizCreatePage> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _subject;
  late final TextEditingController _duration;
  late QuizDifficulty _difficulty;
  late final List<_DraftQuestion> _questions;

  bool get _isEditing => widget.quiz != null;

  @override
  void initState() {
    super.initState();
    final quiz = widget.quiz;
    _title = TextEditingController(text: quiz?.title ?? '');
    _description = TextEditingController(text: quiz?.description ?? '');
    _subject = TextEditingController(text: quiz?.subject ?? 'Java');
    _duration = TextEditingController(text: '${quiz?.estimatedMinutes ?? 15}');
    _difficulty = quiz?.difficulty ?? QuizDifficulty.moyen;
    _questions = quiz == null || quiz.questions.isEmpty
        ? [_DraftQuestion()]
        : [for (final question in quiz.questions) _DraftQuestion.fromQuestion(question)];
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _subject.dispose();
    _duration.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() => _questions.add(_DraftQuestion()));
  }

  void _removeQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() {
      _questions.removeAt(index).dispose();
    });
  }

  void _save() {
    final vm = QuizScope.of(context);
    final minutes = int.tryParse(_duration.text.trim()) ?? 0;
    final questions = [
      for (var i = 0; i < _questions.length; i++)
        Question(
          id: widget.quiz != null && i < widget.quiz!.questions.length
              ? widget.quiz!.questions[i].id
              : 'q-$i',
          text: _questions[i].text.text,
          options: [for (final option in _questions[i].options) option.text],
          correctIndex: _questions[i].correctIndex,
        ),
    ];

    final draft = Quiz(
      id: widget.quiz?.id ?? '',
      title: _title.text,
      description: _description.text.trim(),
      subject: _subject.text,
      difficulty: _difficulty,
      estimatedMinutes: minutes,
      questions: questions,
      generatedByAi: widget.quiz?.generatedByAi ?? false,
    );

    final saved = _isEditing ? vm.updateQuiz(draft) : vm.createQuiz(draft);
    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: QuizTokens.danger,
          content: Text(
            vm.errorMessage ?? 'Impossible d’enregistrer le quiz.',
            style: QuizTokens.body(14, color: Colors.white),
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: QuizTokens.text,
        content: Text(
          _isEditing ? 'Quiz mis à jour.' : 'Quiz créé.',
          style: QuizTokens.body(14, color: Colors.white),
        ),
      ),
    );

    if (_isEditing) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => QuizDetailPage(quizId: saved.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_isEditing ? 'Modifier le quiz' : 'Créer un quiz'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Titre du quiz'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    minLines: 3,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subject,
                    decoration: const InputDecoration(labelText: 'Matière'),
                  ),
                  const SizedBox(height: 16),
                  Text('Difficulté', style: QuizTokens.body(14, weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final difficulty in QuizDifficulty.values)
                        DifficultyChip(
                          difficulty: difficulty,
                          selected: _difficulty == difficulty,
                          onTap: () => setState(() => _difficulty = difficulty),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Durée (minutes)'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('Questions', style: QuizTokens.heading(18)),
                      const Spacer(),
                      Text(
                        '${_questions.length} prévue(s)',
                        style: QuizTokens.body(13, color: QuizTokens.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _questions.length; i++) _questionEditor(i),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addQuestion,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter une question'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                16 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(_isEditing ? 'Enregistrer les modifications' : 'Enregistrer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionEditor(int index) {
    final question = _questions[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: QuizTokens.card,
          borderRadius: BorderRadius.circular(QuizTokens.rCard),
          boxShadow: QuizTokens.shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${index + 1}',
                    style: QuizTokens.body(14, weight: FontWeight.w700),
                  ),
                ),
                if (_questions.length > 1)
                  IconButton(
                    tooltip: 'Supprimer la question',
                    onPressed: () => _removeQuestion(index),
                    icon: const Icon(Icons.delete_outline, color: QuizTokens.danger),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: question.text,
              decoration: const InputDecoration(hintText: 'Énoncé de la question'),
            ),
            const SizedBox(height: 12),
            for (var k = 0; k < 4; k++) ...[
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => question.correctIndex = k),
                    icon: Icon(
                      question.correctIndex == k
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: question.correctIndex == k ? QuizTokens.primary : QuizTokens.muted,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: question.options[k],
                      decoration: InputDecoration(hintText: 'Proposition ${'ABCD'[k]}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Cochez la bonne réponse.',
              style: QuizTokens.body(12, color: QuizTokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}
