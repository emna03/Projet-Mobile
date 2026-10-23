import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../theme/quiz_theme.dart';
import '../viewmodels/quiz_viewmodel.dart';
import '../widgets/difficulty_chip.dart';
import 'quiz_create_page.dart';
import 'quiz_play_page.dart';

class QuizDetailPage extends StatelessWidget {
  const QuizDetailPage({super.key, required this.quizId});

  final String quizId;

  Future<void> _confirmDelete(BuildContext context, QuizViewModel vm, Quiz quiz) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer ce quiz ?'),
          content: Text('« ${quiz.title} » sera retiré de la liste. Cette action est irréversible dans cette session.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Supprimer',
                style: QuizTokens.body(14, color: QuizTokens.danger, weight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    vm.deleteQuiz(quiz.id);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: QuizTokens.text,
        content: Text(
          'Quiz « ${quiz.title} » supprimé.',
          style: QuizTokens.body(14, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = QuizScope.of(context);
    final quiz = vm.quizById(quizId);

    if (quiz == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Détail du quiz'),
        ),
        body: const Center(child: Text('Ce quiz n’existe plus.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Détail du quiz'),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => QuizCreatePage(quiz: quiz)),
              );
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Supprimer',
            onPressed: () => _confirmDelete(context, vm, quiz),
            icon: const Icon(Icons.delete_outline, color: QuizTokens.danger),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(quiz.title, style: QuizTokens.heading(26)),
                  const SizedBox(height: 8),
                  Text(quiz.description, style: QuizTokens.body(15, color: QuizTokens.muted)),
                  const SizedBox(height: 20),
                  _InfoCard(
                    children: [
                      _InfoRow(Icons.menu_book_outlined, 'Matière', quiz.subject),
                      _InfoRow(
                        Icons.signal_cellular_alt,
                        'Difficulté',
                        quiz.difficulty.label,
                        trailing: DifficultyChip(difficulty: quiz.difficulty),
                      ),
                      _InfoRow(Icons.help_outline, 'Questions', '${quiz.questionCount}'),
                      _InfoRow(Icons.schedule, 'Durée estimée', '${quiz.estimatedMinutes} min'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: QuizTokens.card,
                      borderRadius: BorderRadius.circular(QuizTokens.rCard),
                      boxShadow: QuizTokens.shadow,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: QuizTokens.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'QCM à choix unique. Validez chaque réponse avant de passer à la suivante. Le score est ajouté à l’historique.',
                            style: QuizTokens.body(14, color: QuizTokens.muted),
                          ),
                        ),
                      ],
                    ),
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
                  onPressed: () {
                    vm.startQuiz(quiz);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const QuizPlayPage()),
                    );
                  },
                  child: const Text('Commencer le quiz'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: QuizTokens.card,
        borderRadius: BorderRadius.circular(QuizTokens.rCard),
        boxShadow: QuizTokens.shadow,
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value, {this.trailing});

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: QuizTokens.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: QuizTokens.body(12, color: QuizTokens.muted)),
                Text(value, style: QuizTokens.body(15, weight: FontWeight.w600)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
