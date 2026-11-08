import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../models/knowledge_edge.dart';
import '../models/mastery_level.dart';
import '../services/concept_layout.dart';

Color masteryColor(MasteryLevel level) => switch (level) {
      MasteryLevel.unevalue => const Color(0xFF9CA3AF),
      MasteryLevel.faible => const Color(0xFFEF4444),
      MasteryLevel.moyenne => SM.accent,
      MasteryLevel.bonne => SM.success,
      MasteryLevel.excellente => const Color(0xFF059669),
    };

class KnowledgeGraphPainter extends CustomPainter {
  KnowledgeGraphPainter({
    required this.nodes,
    required this.edges,
    this.selectedId,
  });

  final List<GraphNodeLayout> nodes;
  final List<KnowledgeEdge> edges;
  final String? selectedId;

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final n in nodes) n.conceptId: n};
    final edgePaint = Paint()
      ..color = SM.primary.withValues(alpha: 0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final e in edges) {
      final a = byId[e.fromConceptId];
      final b = byId[e.toConceptId];
      if (a == null || b == null) continue;
      canvas.drawLine(a.position, b.position, edgePaint);
      if (e.relationType == 'prerequisite') {
        _drawArrow(canvas, a.position, b.position, edgePaint);
      }
    }

    for (final n in nodes) {
      final selected = n.conceptId == selectedId;
      final fill = Paint()..color = masteryColor(n.level);
      final glow = Paint()
        ..color = masteryColor(n.level).withValues(alpha: selected ? 0.35 : 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(n.position, n.radius + (selected ? 10 : 4), glow);
      canvas.drawCircle(n.position, n.radius, fill);
      canvas.drawCircle(
        n.position,
        n.radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 1.5,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: n.label.length > 16 ? '${n.label.substring(0, 14)}…' : n.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: n.radius * 2.2);
      tp.paint(
        canvas,
        n.position - Offset(tp.width / 2, tp.height / 2),
      );
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final dir = (to - from);
    if (dir.distance < 1) return;
    final unit = dir / dir.distance;
    final tip = to - unit * 28;
    final ortho = Offset(-unit.dy, unit.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - unit.dx * 10 + ortho.dx * 5,
        tip.dy - unit.dy * 10 + ortho.dy * 5,
      )
      ..lineTo(
        tip.dx - unit.dx * 10 - ortho.dx * 5,
        tip.dy - unit.dy * 10 - ortho.dy * 5,
      )
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant KnowledgeGraphPainter oldDelegate) {
    return oldDelegate.selectedId != selectedId ||
        oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges;
  }
}
