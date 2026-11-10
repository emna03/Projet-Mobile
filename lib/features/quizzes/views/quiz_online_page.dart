import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../services/open_trivia_service.dart';
import '../theme/quiz_theme.dart';
import '../viewmodels/quiz_viewmodel.dart';
import '../widgets/difficulty_chip.dart';
import 'quiz_play_page.dart';

class QuizOnlinePage extends StatelessWidget {
  const QuizOnlinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = QuizScope.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Quiz en ligne'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text('Quiz prêts à jouer', style: QuizTokens.heading(22)),
            const SizedBox(height: 6),
            Text(
              'Explorez différentes catégories et testez vos connaissances '
              'avec des quiz préparés.',
              style: QuizTokens.body(13, color: QuizTokens.muted),
            ),
            const SizedBox(height: 20),
            Text('Catégorie', style: QuizTokens.body(14, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButtonFormField<OpenTriviaCategory>(
              initialValue: vm.onlineCategory,
              items: [
                for (final category in OpenTriviaService.categories)
                  DropdownMenuItem(value: category, child: Text(category.name)),
              ],
              onChanged: (value) {
                if (value != null) vm.setOnlineCategory(value);
              },
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
                    selected: vm.onlineDifficulty == difficulty,
                    onTap: () => vm.setOnlineDifficulty(difficulty),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Nombre de questions', style: QuizTokens.body(14, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final count in const [5, 10, 15])
                  FilterChip(
                    label: Text('$count'),
                    selected: vm.onlineQuestionCount == count,
                    onSelected: (_) => vm.setOnlineQuestionCount(count),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: vm.isFetchingOnline
                  ? null
                  : () async {
                      await vm.fetchOnlineQuiz();
                      if (!context.mounted) return;
                      if (vm.errorMessage != null && vm.onlineQuiz == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: QuizTokens.danger,
                            content: Text(
                              vm.errorMessage!,
                              style: QuizTokens.body(14, color: Colors.white),
                            ),
                          ),
                        );
                      }
                    },
              child: Text(vm.isFetchingOnline ? 'Chargement…' : 'Charger des questions'),
            ),
            if (vm.isFetchingOnline) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (vm.onlineQuiz != null && !vm.isFetchingOnline) ...[
              const SizedBox(height: 24),
              _OnlinePreview(quiz: vm.onlineQuiz!),
            ],
            const SizedBox(height: 28),
            Text('Sources et crédits', style: QuizTokens.body(14, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Une partie des questions provient d’Open Trivia Database, '
              'distribuée sous licence CC BY-SA 4.0.',
              style: QuizTokens.body(12, color: QuizTokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlinePreview extends StatelessWidget {
  const _OnlinePreview({required this.quiz});
  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: QuizTokens.card,
        borderRadius: BorderRadius.circular(QuizTokens.rCard),
        boxShadow: QuizTokens.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(quiz.title, style: QuizTokens.heading(18)),
          const SizedBox(height: 8),
          Text(
            '${quiz.questionCount} questions · ${quiz.difficulty.label}',
            style: QuizTokens.body(13, weight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final vm = QuizScope.of(context);
              final saved = await vm.saveOnlineQuiz() ?? quiz;
              if (!context.mounted) return;
              vm.startQuiz(saved, source: 'opentdb');
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const QuizPlayPage()),
              );
            },
            child: const Text('Jouer maintenant'),
          ),
          TextButton(
            onPressed: () async {
              final saved = await QuizScope.of(context).saveOnlineQuiz();
              if (saved == null || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Quiz « ${saved.title} » enregistré.')),
              );
            },
            child: const Text('Enregistrer seulement'),
          ),
        ],
      ),
    );
  }
}
