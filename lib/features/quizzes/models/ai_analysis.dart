class AiAnalysis {
  const AiAnalysis({
    required this.personalizedExplanation,
    required this.topicsToReview,
    required this.revisionTips,
    required this.nextDifficulty,
  });

  final String personalizedExplanation;
  final List<String> topicsToReview;
  final List<String> revisionTips;
  final String nextDifficulty;

  Map<String, dynamic> toJson() => {
        'personalizedExplanation': personalizedExplanation,
        'topicsToReview': topicsToReview,
        'revisionTips': revisionTips,
        'nextDifficulty': nextDifficulty,
      };

  factory AiAnalysis.fromJson(Map<String, dynamic> json) {
    List<String> asStringList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return const [];
    }

    final tips = asStringList(json['revisionTips']);
    while (tips.length < 3) {
      tips.add('Revois les notions liées à tes erreurs.');
    }

    return AiAnalysis(
      personalizedExplanation:
          json['personalizedExplanation']?.toString().trim().isNotEmpty == true
              ? json['personalizedExplanation'].toString().trim()
              : 'Analyse indisponible.',
      topicsToReview: asStringList(json['topicsToReview']),
      revisionTips: tips.take(3).toList(),
      nextDifficulty: json['nextDifficulty']?.toString().trim().isNotEmpty == true
          ? json['nextDifficulty'].toString().trim()
          : 'moyen',
    );
  }
}
