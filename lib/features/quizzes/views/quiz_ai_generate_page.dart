import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../services/quiz_ai_provider.dart';
import '../theme/quiz_theme.dart';
import '../viewmodels/quiz_viewmodel.dart';
import '../widgets/difficulty_chip.dart';
import 'quiz_create_page.dart';
import 'quiz_play_page.dart';

class QuizAiGeneratePage extends StatefulWidget {
  const QuizAiGeneratePage({super.key});

  @override
  State<QuizAiGeneratePage> createState() => _QuizAiGeneratePageState();
}

class _QuizAiGeneratePageState extends State<QuizAiGeneratePage> {
  late final TextEditingController _topicController;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      QuizScope.of(context).applySuggestedDifficultyToForms();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final topic = QuizScope.of(context).aiTopic;
    if (_topicController.text.isEmpty && topic.isNotEmpty) {
      _topicController.text = topic;
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = QuizScope.of(context);
    final configured = vm.activeAiConfigured;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F1FF),
        leading: const BackButton(),
        title: const Text('Génération intelligente'),
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
                    'Génération intelligente de quiz',
                    style: QuizTokens.heading(22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Créez un questionnaire adapté à votre cours en quelques secondes.',
              style: QuizTokens.body(13, color: QuizTokens.muted),
            ),
            const SizedBox(height: 16),
            Text('Profil de génération', style: QuizTokens.body(14, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<AiProviderKind>(
              segments: [
                for (final kind in AiProviderKind.values)
                  ButtonSegment(
                    value: kind,
                    label: Text(
                      kind == AiProviderKind.gemini
                          ? 'Profil principal'
                          : 'Profil alternatif',
                    ),
                    icon: Icon(
                      kind == AiProviderKind.gemini
                          ? Icons.auto_awesome
                          : Icons.hub_outlined,
                      size: 18,
                    ),
                  ),
              ],
              selected: {vm.selectedAiProvider},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) vm.setAiProvider(set.first);
              },
            ),
            const SizedBox(height: 8),
            Text(
              configured
                  ? 'La génération intelligente est prête. Les questions sont produites à la demande.'
                  : 'La génération intelligente n’est pas encore activée sur cet appareil. '
                      'Importez la configuration fournie par votre établissement, '
                      'ou contactez l’administrateur StudyMate.',
              style: QuizTokens.body(13, color: QuizTokens.muted),
            ),
            if (!configured) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: vm.isLoadingStore
                    ? null
                    : () async {
                        final ok = await vm.importActiveProviderKeyFromClipboard();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Génération intelligente activée.'
                                  : (vm.errorMessage ??
                                      'Configuration invalide ou presse-papiers vide.'),
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.content_paste_go_outlined, size: 18),
                label: const Text('Importer la configuration'),
              ),
            ],
            if (vm.suggestedDifficulty != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: QuizTokens.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Difficulté adaptée : ${vm.suggestedDifficulty!.label}'
                  '${vm.difficultySuggestionReason != null ? '\n${vm.difficultySuggestionReason}' : ''}',
                  style: QuizTokens.body(13),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Sujet ou contenu du cours', style: QuizTokens.body(14, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _topicController,
              maxLines: 4,
              onChanged: vm.setAiTopic,
              decoration: const InputDecoration(
                hintText: 'Ex. : Spring Boot — injection de dépendances, REST, JPA…',
              ),
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
                    selected: vm.aiDifficulty == difficulty,
                    onTap: () => vm.setAiDifficulty(difficulty),
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
                    selected: vm.aiQuestionCount == count,
                    onSelected: (_) => vm.setAiQuestionCount(count),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: QuizTokens.ai),
              onPressed: vm.isGenerating
                  ? null
                  : () async {
                      vm.setAiTopic(_topicController.text);
                      await vm.generateAiQuiz();
                      if (!context.mounted) return;
                      if (vm.errorMessage != null && vm.generatedQuiz == null) {
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
              child: Text(vm.isGenerating ? 'Génération…' : 'Générer mon quiz'),
            ),
            if (vm.isGenerating) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator(color: QuizTokens.ai)),
              const SizedBox(height: 12),
              Text(
                'Génération intelligente en cours…',
                textAlign: TextAlign.center,
                style: QuizTokens.body(14, color: QuizTokens.muted),
              ),
            ],
            if (vm.generatedQuiz != null && !vm.isGenerating) ...[
              const SizedBox(height: 24),
              _GeneratedPreview(quiz: vm.generatedQuiz!),
            ],
            const SizedBox(height: 28),
            Text(
              'Sources et crédits',
              style: QuizTokens.body(14, weight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'La génération intelligente s’appuie sur des services d’IA '
              '(notamment Gemini et OpenRouter) selon la configuration de votre établissement.',
              style: QuizTokens.body(12, color: QuizTokens.muted),
            ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(quiz.title, style: QuizTokens.heading(18)),
          const SizedBox(height: 8),
          Text(quiz.description, style: QuizTokens.body(13, color: QuizTokens.muted)),
          const SizedBox(height: 10),
          Text(
            '${quiz.subject} · ${quiz.questionCount} questions · ${quiz.estimatedMinutes} min',
            style: QuizTokens.body(13, weight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < quiz.questions.length && i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Q${i + 1}. ${quiz.questions[i].text}',
                style: QuizTokens.body(13),
              ),
            ),
          if (quiz.questions.length > 3)
            Text(
              '+ ${quiz.questions.length - 3} autres questions',
              style: QuizTokens.body(12, color: QuizTokens.muted),
            ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => QuizCreatePage(quiz: quiz),
                ),
              );
            },
            child: const Text('Modifier avant enregistrement'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: QuizTokens.ai),
            onPressed: () async {
              final vm = QuizScope.of(context);
              final saved = await vm.saveGeneratedQuiz() ?? quiz;
              if (!context.mounted) return;
              vm.startQuiz(saved, source: vm.selectedAiProvider.shortId);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const QuizPlayPage()),
              );
            },
            child: const Text('Enregistrer et lancer'),
          ),
          TextButton(
            onPressed: () async {
              final saved = await QuizScope.of(context).saveGeneratedQuiz();
              if (saved == null || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: QuizTokens.text,
                  content: Text(
                    'Quiz « ${saved.title} » enregistré.',
                    style: QuizTokens.body(14, color: Colors.white),
                  ),
                ),
              );
            },
            child: const Text('Enregistrer dans mes quiz'),
          ),
        ],
      ),
    );
  }
}
