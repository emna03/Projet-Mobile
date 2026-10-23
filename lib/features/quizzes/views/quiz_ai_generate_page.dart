import 'package:flutter/material.dart';

import '../data/quiz_mock_data.dart';
import '../models/quiz.dart';
import '../theme/quiz_theme.dart';
import '../viewmodels/quiz_viewmodel.dart';
import '../widgets/difficulty_chip.dart';
import 'quiz_play_page.dart';

class QuizAiGeneratePage extends StatelessWidget {
  const QuizAiGeneratePage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = QuizScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F1FF),
        leading: const BackButton(),
        title: const Text('Génération IA'),
      ),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: QuizTokens.aiSoft,
                    borderRadius: BorderRadius.circular(QuizTokens.rButton),
                  ),
                  child: const Icon(Icons.auto_awesome, color: QuizTokens.ai),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Générer un quiz avec l’IA',
                    style: QuizTokens.heading(22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Démonstration locale. Aucun modèle d’intelligence artificielle n’est appelé.',
              style: QuizTokens.body(13, color: QuizTokens.muted),
            ),
            const SizedBox(height: 20),
            Text('Ressource pédagogique', style: QuizTokens.body(14, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final resource in mockResources)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(QuizTokens.rCard),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(QuizTokens.rCard),
                    onTap: () => vm.selectResource(resource),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(
                            vm.selectedResource.id == resource.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: vm.selectedResource.id == resource.id
                                ? QuizTokens.ai
                                : QuizTokens.muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(resource.title, style: QuizTokens.body(15))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text('Difficulté', style: QuizTokens.body(14, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final difficulty in QuizDifficulty.values)
                  DifficultyChip(
                    difficulty: difficulty,
                    selected: vm.aiDifficulty == difficulty,
                    onTap: () => vm.setAiDifficulty(difficulty),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Nombre de questions : ${vm.aiQuestionCount}',
              style: QuizTokens.body(14, weight: FontWeight.w600),
            ),
            Slider(
              value: vm.aiQuestionCount.toDouble(),
              min: 5,
              max: 20,
              divisions: 15,
              label: '${vm.aiQuestionCount}',
              onChanged: vm.setAiQuestionCount,
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: QuizTokens.aiSoft,
                borderRadius: BorderRadius.circular(QuizTokens.rCard),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: QuizTokens.ai),
                  const SizedBox(width: 8),
                  Text(
                    'Durée estimée : ${vm.estimatedAiMinutes} min',
                    style: QuizTokens.body(14, color: QuizTokens.ai, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: QuizTokens.ai),
                onPressed: vm.isGenerating ? null : vm.generateAiQuiz,
                child: Text(vm.isGenerating ? 'Génération…' : 'Générer le quiz'),
              ),
            ),
            if (vm.isGenerating) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator(color: QuizTokens.ai)),
              const SizedBox(height: 12),
              Text(
                'Préparation d’un quiz fictif…',
                textAlign: TextAlign.center,
                style: QuizTokens.body(14, color: QuizTokens.muted),
              ),
            ],
            if (vm.generatedQuiz != null && !vm.isGenerating) ...[
              const SizedBox(height: 24),
              _GeneratedPreview(quiz: vm.generatedQuiz!),
            ],
          ],
        ),
      ),
    );
  }
}

class _GeneratedPreview extends StatelessWidget {
  const _GeneratedPreview({required this.quiz});

  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(QuizTokens.rCard),
        boxShadow: QuizTokens.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quiz.title, style: QuizTokens.heading(18)),
          const SizedBox(height: 6),
          Text(quiz.description, style: QuizTokens.body(13, color: QuizTokens.muted)),
          const SizedBox(height: 12),
          Text(
            '${quiz.subject} · ${quiz.questionCount} questions · ${quiz.estimatedMinutes} min',
            style: QuizTokens.body(13, weight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: QuizTokens.ai),
              onPressed: () {
                final vm = QuizScope.of(context);
                final saved = vm.saveGeneratedQuiz() ?? quiz;
                vm.startQuiz(saved);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const QuizPlayPage()),
                );
              },
              child: const Text('Enregistrer et commencer'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                final saved = QuizScope.of(context).saveGeneratedQuiz();
                if (saved == null) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: QuizTokens.text,
                    content: Text(
                      'Quiz « ${saved.title} » ajouté à la liste.',
                      style: QuizTokens.body(14, color: Colors.white),
                    ),
                  ),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Enregistrer dans mes quiz'),
            ),
          ),
        ],
      ),
    );
  }
}
