import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/knowledge_edge.dart';
import '../models/mastery_level.dart';
import '../models/student_concept_mastery.dart';

class GraphNodeLayout {
  GraphNodeLayout({
    required this.conceptId,
    required this.label,
    required this.level,
    required this.score,
    required this.position,
    this.radius = 28,
  });

  final String conceptId;
  final String label;
  final MasteryLevel level;
  final double score;
  Offset position;
  final double radius;
}

/// Disposition circulaire + léger ressort pour éviter les chevauchements.
class ConceptLayoutEngine {
  const ConceptLayoutEngine();

  List<GraphNodeLayout> layout({
    required List<({String id, String label, MasteryLevel level, double score})>
        nodes,
    required List<KnowledgeEdge> edges,
    required Size canvasSize,
  }) {
    if (nodes.isEmpty) return const [];
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final radius = math.min(canvasSize.width, canvasSize.height) * 0.32;
    final result = <GraphNodeLayout>[];

    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final angle = (2 * math.pi * i) / nodes.length - math.pi / 2;
      final r = nodes.length == 1 ? 0.0 : radius;
      result.add(
        GraphNodeLayout(
          conceptId: n.id,
          label: n.label,
          level: n.level,
          score: n.score,
          position: center + Offset(math.cos(angle) * r, math.sin(angle) * r),
          radius: 22 + (n.score / 100) * 14,
        ),
      );
    }

    // Quelques itérations de répulsion simple
    for (var iter = 0; iter < 40; iter++) {
      for (var i = 0; i < result.length; i++) {
        for (var j = i + 1; j < result.length; j++) {
          final a = result[i];
          final b = result[j];
          final delta = a.position - b.position;
          final dist = delta.distance.clamp(1.0, 400.0);
          final minDist = a.radius + b.radius + 24;
          if (dist < minDist) {
            final push = (minDist - dist) / 2;
            final dir = delta / dist;
            a.position += dir * push;
            b.position -= dir * push;
          }
        }
      }
    }
    return result;
  }

  MasteryLevel levelFor(
    String conceptId,
    List<StudentConceptMastery> masteries,
  ) {
    for (final m in masteries) {
      if (m.conceptId == conceptId) return m.level;
    }
    return MasteryLevel.unevalue;
  }
}
