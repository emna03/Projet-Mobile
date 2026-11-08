class KnowledgeDashboardStats {
  const KnowledgeDashboardStats({
    required this.globalMasteryPercent,
    required this.conceptCount,
    required this.masteredCount,
    required this.toImproveCount,
    required this.unevaluatedCount,
    this.lastUpdated,
  });

  final double globalMasteryPercent;
  final int conceptCount;
  final int masteredCount;
  final int toImproveCount;
  final int unevaluatedCount;
  final DateTime? lastUpdated;

  static const empty = KnowledgeDashboardStats(
    globalMasteryPercent: 0,
    conceptCount: 0,
    masteredCount: 0,
    toImproveCount: 0,
    unevaluatedCount: 0,
  );
}
