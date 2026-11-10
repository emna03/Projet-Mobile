import 'package:flutter/material.dart';

import '../data/quiz_local_database.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import 'models/knowledge_enrichment_report.dart';
import 'services/concept_extraction_service.dart';
import 'services/knowledge_ai_client.dart';
import 'services/knowledge_graph_engine.dart';
import 'services/local_llm/kg_llm_config.dart';
import 'services/local_llm/local_knowledge_llm_service.dart';
import 'services/local_llm/local_model_manager.dart';

/// Smoke device-only du LLM local Knowledge Map.
///
/// ```bash
/// flutter run -t lib/features/quizzes/knowledge_graph/kg_llm_smoke_main.dart -d <device>
/// ```
///
/// Ne remplace pas `main.dart`. Affiche le résultat à l’écran + logs.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QuizLocalDatabase.instance.database;

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: _KgLlmSmokePage(),
  ));
}

class _KgLlmSmokePage extends StatefulWidget {
  const _KgLlmSmokePage();

  @override
  State<_KgLlmSmokePage> createState() => _KgLlmSmokePageState();
}

class _KgLlmSmokePageState extends State<_KgLlmSmokePage> {
  final _lines = <String>[];
  var _running = true;

  void _log(String m) {
    debugPrint('KG SMOKE: $m');
    setState(() => _lines.add(m));
  }

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _run();
  }

  Future<void> _run() async {
    final quiz = Quiz(
      id: 'smoke-llm-1',
      title: 'Bases Java',
      description: 'Smoke',
      subject: 'Java',
      difficulty: QuizDifficulty.facile,
      estimatedMinutes: 5,
      questions: const [
        Question(
          id: 'q1',
          text: 'Qu’est-ce qu’une classe en Java ?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          explanation: 'Modèle pour créer des objets',
        ),
        Question(
          id: 'q2',
          text: 'Le mot-clé extends sert à ?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 1,
          explanation: 'Héritage entre classes',
        ),
        Question(
          id: 'q3',
          text: 'Une interface définit ?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 2,
          explanation: 'Contrat de méthodes',
        ),
      ],
    );

    try {
      final mgr = LocalModelManager();
      final available = await mgr.isModelAvailable();
      _log('modelAvailable=$available ${mgr.lastStatusMessage ?? ''}');
      if (!available) {
        _log('FAIL: GGUF absent');
        setState(() => _running = false);
        return;
      }

      final llm = LocalKnowledgeLlmService(modelManager: mgr);
      final extraction = ConceptExtractionService();
      final prompt = extraction.buildExtractionPrompt(quiz);
      _log('[load/gen] promptChars=${prompt.length} '
          'model=${KgLlmConfig.displayName}');

      final engine = KnowledgeGraphEngine(
        aiClient: KnowledgeAiClient(
          localLlm: llm,
          availabilityProbe: () async => true,
        ),
      );

      // 1er passage : force LLM (pas de cache).
      final detailed = await engine.ensureConceptsForQuizDetailed(
        quiz,
        allowNetwork: true,
        upgradeHeuristicCache: true,
      );
      _log('[save] path=${detailed.path.name} '
          'concepts=${detailed.result.concepts.length} '
          'relations=${detailed.result.relations.length} '
          'source=${detailed.result.source}');
      for (final c in detailed.result.concepts) {
        _log('  concept: ${c.name}');
      }
      if (detailed.path != KnowledgeExtractionPath.localLlm &&
          detailed.path != KnowledgeExtractionPath.cacheAi) {
        throw StateError(
          'Attendu localLlm/cacheAi, obtenu ${detailed.path.name} '
          '(${engine.lastAiFailureSummary})',
        );
      }

      // 2e génération successive (hors cache, prompt direct).
      final raw2 = await llm.complete(prompt);
      final parsed2 = extraction.parseAiPayload(raw2, quiz);
      _log('[gen2] OK concepts=${parsed2.concepts.length}');

      await llm.unload();
      engine.dispose();
      _log('SUCCESS local LLM end-to-end');
    } catch (e, st) {
      _log('FAIL: $e');
      debugPrint('$st');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KG LLM Smoke')),
      body: Column(
        children: [
          if (_running) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _lines.length,
              itemBuilder: (_, i) => Text(
                _lines[i],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
