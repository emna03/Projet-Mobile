/// Chemin d’extraction pour un quiz (jamais de secrets dedans).
enum KnowledgeExtractionPath {
  /// Cache valide produit précédemment par le LLM local.
  cacheAi,

  /// Cache valide produit par l’heuristique locale.
  cacheHeuristic,

  /// Inférence LLM locale réussie (on-device).
  localLlm,

  /// LLM tenté puis échec → fallback heuristique.
  fallbackHeuristic,

  /// Heuristique locale sans tentative LLM (modèle absent / offline forcé).
  localHeuristic,

  /// Quiz sans questions — ignoré (pas un échec LLM).
  skippedEmpty,
}

/// Agrégat après un enrichissement ✨ (messages UI uniquement).
class KnowledgeEnrichmentReport {
  const KnowledgeEnrichmentReport({
    required this.aiConfigured,
    required this.quizCount,
    required this.localLlmCount,
    required this.cacheAiCount,
    required this.cacheHeuristicCount,
    required this.fallbackHeuristicCount,
    required this.localHeuristicCount,
    this.skippedEmptyCount = 0,
    this.failureDetail,
  });

  final bool aiConfigured;
  /// Quiz avec id non vide rencontrés (y compris vides de questions).
  final int quizCount;
  final int localLlmCount;
  final int cacheAiCount;
  final int cacheHeuristicCount;
  final int fallbackHeuristicCount;
  final int localHeuristicCount;
  final int skippedEmptyCount;

  /// Cause sanitisée — jamais de clé API.
  final String? failureDetail;

  bool get usedLocalLlm => localLlmCount > 0;
  bool get usedFallback => fallbackHeuristicCount > 0;
  bool get hasPriorAiCache => cacheAiCount > 0;

  /// Quiz réellement traités (hors vides ignorés).
  int get actionableQuizCount =>
      (quizCount - skippedEmptyCount).clamp(0, quizCount);

  /// Couverture IA (nouvelle gén. + cache AI déjà présent).
  int get aiCoveredCount => localLlmCount + cacheAiCount;

  /// Message utilisateur — reflète le mix réel, sans faux succès LLM.
  String get userMessage {
    if (!aiConfigured) {
      return 'LLM local non disponible. Installez le modèle GGUF '
          '(Qwen2.5-0.5B Q4_K_M) — voir MODEL_INSTALL.md.';
    }

    if (quizCount == 0) {
      return 'Aucun quiz à enrichir. Créez ou importez un quiz d’abord.';
    }

    if (actionableQuizCount == 0 && skippedEmptyCount > 0) {
      return 'Aucun quiz exploitable ($skippedEmptyCount sans questions). '
          'Rien à enrichir (ignorés, hors LLM).';
    }

    final hint = _shortFailureHint;

    // Succès strict : au moins une nouvelle inférence, aucun fallback.
    if (usedLocalLlm && !usedFallback) {
      final cacheNote = hasPriorAiCache
          ? ' (+$cacheAiCount déjà en cache IA)'
          : '';
      return 'Enrichissement LLM local réussi ($localLlmCount quiz)$cacheNote. '
          'Graphe et recommandations mis à jour.';
    }

    // Mix nouvelle gen + fallback.
    if (usedLocalLlm && usedFallback) {
      return 'Enrichissement partiel : $localLlmCount quiz via LLM local, '
          '$fallbackHeuristicCount en heuristique (pas un LLM).'
          '${hint == null ? '' : ' Détail : $hint'}';
    }

    // Pas de nouvelle gen, mais cache AI + fallback sur d’autres.
    if (!usedLocalLlm && hasPriorAiCache && usedFallback) {
      return 'Résultat mixte : $cacheAiCount quiz déjà enrichis (cache LLM), '
          '$fallbackHeuristicCount en heuristique après échec d’extraction '
          '(ce n’est pas une génération LLM).'
          '${hint == null ? '' : ' Détail : $hint'}';
    }

    // Échec réel : aucune couverture AI (ni cache ni nouvelle gen).
    if (usedFallback && !usedLocalLlm && !hasPriorAiCache) {
      return hint == null
          ? 'LLM local en échec. Extraction heuristique utilisée '
              '(ce n’est pas une génération LLM).'
          : 'LLM local en échec ($hint). Extraction heuristique utilisée '
              '(ce n’est pas une génération LLM).';
    }

    // Uniquement cache AI.
    if (hasPriorAiCache &&
        !usedLocalLlm &&
        !usedFallback &&
        localHeuristicCount == 0) {
      return 'Déjà enrichi via LLM local (cache à jour, $cacheAiCount quiz). '
          'Aucune nouvelle inférence.';
    }

    if (cacheHeuristicCount > 0 &&
        !usedLocalLlm &&
        !hasPriorAiCache &&
        !usedFallback) {
      return 'Cache heuristique conservé. Relancez ✨ pour retenter '
          'l’enrichissement LLM local.';
    }

    if (skippedEmptyCount > 0) {
      return 'Actualisation terminée ($skippedEmptyCount quiz vides ignorés).';
    }

    return 'Actualisation locale terminée (heuristique, pas LLM).';
  }

  String? get _shortFailureHint {
    final d = failureDetail?.trim();
    if (d == null || d.isEmpty) return null;
    return d.length > 100 ? '${d.substring(0, 100)}…' : d;
  }

  /// Succès LLM strict : au moins une **nouvelle** inférence locale réussie.
  bool get isAiSuccess => usedLocalLlm;

  /// Outcome UI « positif » (vert) : nouvelle gen LLM sans fallback.
  /// Le mix cache+fallback reste ambre (pas un faux succès LLM).
  bool get isPositiveOutcome => usedLocalLlm && !usedFallback;
}
