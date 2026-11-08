/// Métadonnées du LLM embarqué pour My Knowledge Map (aucun secret).
///
/// Modèle : Qwen2.5-0.5B-Instruct, quantification Q4_K_M (GGUF).
/// Licence : Apache 2.0 (Qwen) — fichier à obtenir depuis Hugging Face
/// (voir `MODEL_INSTALL.md` dans ce dossier).
class KgLlmConfig {
  KgLlmConfig._();

  static const displayName = 'Qwen2.5-0.5B-Instruct';
  static const parametersLabel = '0.5B';
  static const quantization = 'Q4_K_M';
  static const engineLabel = 'llama.cpp (llama_flutter_android)';

  /// Nom de fichier attendu sous le répertoire documents de l’app.
  static const fileName = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';

  /// Sous-dossier dans ApplicationDocumentsDirectory.
  static const documentsSubdir = 'studymate_kg_llm';

  /// Taille attendue (~491 Mo) — contrôle d’intégrité grossier.
  static const expectedMinBytes = 400 * 1024 * 1024;
  static const expectedMaxBytes = 550 * 1024 * 1024;

  /// URL publique Hugging Face (téléchargement manuel / script, pas de clé).
  static const huggingfaceResolveUrl =
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/'
      'qwen2.5-0.5b-instruct-q4_k_m.gguf';

  /// Template ChatML (Qwen 2.5) côté plugin llama_flutter_android.
  static const chatTemplate = 'qwen2.5';

  static const systemPrompt =
      'Tu extrais des concepts pédagogiques. '
      'Réponds UNIQUEMENT avec un objet JSON valide. '
      'Pas de markdown, pas de texte hors JSON, pas d’explication.';

  // --- Paramètres adaptés 0.5B Q4 (JSON court) ---
  static const contextSize = 2048;
  static const threads = 4;

  /// Assez pour ~4 concepts + relations ; limite le risque de hang.
  static const maxTokens = 320;

  static const temperature = 0.1;
  static const topP = 0.85;
  static const topK = 20;
  static const repeatPenalty = 1.15;

  /// Questions max injectées dans le prompt (contexte court).
  static const maxQuestionsInPrompt = 4;

  /// Concepts / relations demandés au modèle.
  static const maxConcepts = 4;
  static const maxRelations = 3;
}
