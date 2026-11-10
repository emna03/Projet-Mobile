import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../theme/quiz_theme.dart';
import '../viewmodels/quiz_viewmodel.dart';
import '../widgets/difficulty_chip.dart';
import '../widgets/quiz_card.dart';
import 'quiz_ai_generate_page.dart';
import 'quiz_create_page.dart';
import 'quiz_detail_page.dart';
import 'quiz_history_page.dart';
import '../knowledge_graph/views/knowledge_map_shell.dart';
import 'quiz_online_page.dart';
import 'quiz_results_hub_page.dart';

class QuizListPage extends StatelessWidget {
  const QuizListPage({super.key});

  /// Quitte le module Quiz vers la page parente (Home) sans toucher au
  /// Navigator imbriqué tant qu’il n’a qu’une seule route (liste).
  /// Sans parent (démo standalone), no-op — pas d’écran vide.
  static void leaveModuleIfPossible(BuildContext context) {
    final nested = Navigator.maybeOf(context);
    if (nested != null && nested.canPop()) {
      nested.pop();
      return;
    }
    final outer = Navigator.maybeOf(context, rootNavigator: true);
    if (outer != null && outer.canPop()) {
      outer.pop();
    }
  }

  static bool canLeaveModule(BuildContext context) {
    final nested = Navigator.maybeOf(context);
    if (nested != null && nested.canPop()) return true;
    final outer = Navigator.maybeOf(context, rootNavigator: true);
    return outer != null && outer.canPop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = QuizScope.of(context);
    final quizzes = vm.filteredQuizzes;
    final showBack = canLeaveModule(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const QuizCreatePage()),
          );
        },
        backgroundColor: QuizTokens.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Créer un quiz'),
      ),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            Row(
              children: [
                if (showBack) ...[
                  _HeaderButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Retour',
                    onTap: () => leaveModuleIfPossible(context),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mes Quiz', style: QuizTokens.heading(26)),
                      const SizedBox(height: 4),
                      Text(
                        'Créez, modifiez et lancez vos QCM.',
                        style: QuizTokens.body(14, color: QuizTokens.muted),
                      ),
                    ],
                  ),
                ),
                _HeaderButton(
                  icon: Icons.history,
                  tooltip: 'Historique',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const QuizHistoryPage()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _HeaderButton(
                  icon: Icons.auto_awesome,
                  tooltip: 'Génération intelligente',
                  color: QuizTokens.ai,
                  background: QuizTokens.aiSoft,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const QuizAiGeneratePage()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickNavChip(
                  icon: Icons.list_alt,
                  label: 'Mes Quiz',
                  onTap: () {},
                ),
                _QuickNavChip(
                  icon: Icons.add_circle_outline,
                  label: 'Créer un Quiz',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const QuizCreatePage()),
                    );
                  },
                ),
                _QuickNavChip(
                  icon: Icons.auto_awesome,
                  label: 'Génération intelligente',
                  color: QuizTokens.ai,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const QuizAiGeneratePage()),
                    );
                  },
                ),
                _QuickNavChip(
                  icon: Icons.public,
                  label: 'Quiz prêts à jouer',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const QuizOnlinePage()),
                    );
                  },
                ),
                _QuickNavChip(
                  icon: Icons.insights,
                  label: 'Mes résultats',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const QuizResultsHubPage()),
                    );
                  },
                ),
                _QuickNavChip(
                  icon: Icons.hub_outlined,
                  label: 'Knowledge Map',
                  color: QuizTokens.ai,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const KnowledgeMapShell(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: vm.setSearch,
              decoration: const InputDecoration(
                hintText: 'Rechercher un quiz ou une matière',
                prefixIcon: Icon(Icons.search, color: QuizTokens.muted),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: vm.subjects.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final subject = vm.subjects[index];
                  return FilterChipButton(
                    label: subject,
                    selected: vm.subjectFilter == subject,
                    onTap: () => vm.setSubject(subject),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final difficulty in QuizDifficulty.values)
                  DifficultyChip(
                    difficulty: difficulty,
                    selected: vm.difficultyFilter == difficulty,
                    onTap: () => vm.setDifficulty(difficulty),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (quizzes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text(
                  'Aucun quiz ne correspond à votre recherche.',
                  style: QuizTokens.body(15, color: QuizTokens.muted),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...[
                for (final quiz in quizzes) ...[
                  QuizCard(
                    quiz: quiz,
                    onOpen: () {
                      vm.selectQuiz(quiz);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => QuizDetailPage(quizId: quiz.id)),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
          ],
        ),
      ),
    );
  }
}

class _QuickNavChip extends StatelessWidget {
  const _QuickNavChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = QuizTokens.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color = QuizTokens.primary,
    this.background = QuizTokens.primarySoft,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(QuizTokens.rButton),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(QuizTokens.rButton),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}
