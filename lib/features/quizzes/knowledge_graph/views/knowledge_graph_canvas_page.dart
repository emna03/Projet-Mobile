import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/knowledge_graph_painter.dart';
import 'knowledge_map_shell.dart';

class KnowledgeGraphCanvasPage extends StatefulWidget {
  const KnowledgeGraphCanvasPage({super.key, required this.onOpenDetails});

  final void Function(String conceptId) onOpenDetails;

  @override
  State<KnowledgeGraphCanvasPage> createState() =>
      _KnowledgeGraphCanvasPageState();
}

class _KnowledgeGraphCanvasPageState extends State<KnowledgeGraphCanvasPage> {
  final _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kg = KnowledgeScope.of(context);

    if (kg.concepts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Aucun concept pour l’instant.\nTermine un quiz pour alimenter la carte '
            '(extraction locale même sans IA).',
            textAlign: TextAlign.center,
            style: SM.b(14, color: SM.muted),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Pince pour zoomer · glisser pour naviguer · tape un nœud',
            style: SM.b(12, color: SM.muted),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.maxWidth.clamp(320, 1200),
                constraints.maxHeight.clamp(320, 1200),
              );
              kg.rebuildLayout(size);
              return InteractiveViewer(
                transformationController: _controller,
                minScale: 0.5,
                maxScale: 3,
                boundaryMargin: const EdgeInsets.all(200),
                child: GestureDetector(
                  onTapUp: (details) {
                    final local = details.localPosition;
                    for (final n in kg.layouts) {
                      if ((n.position - local).distance <= n.radius + 8) {
                        kg.selectConcept(n.conceptId);
                        widget.onOpenDetails(n.conceptId);
                        return;
                      }
                    }
                  },
                  child: CustomPaint(
                    size: size,
                    painter: KnowledgeGraphPainter(
                      nodes: kg.layouts,
                      edges: kg.edges,
                      selectedId: kg.selectedConceptId,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            children: const [
              _Legend(color: Color(0xFF9CA3AF), label: 'Non évalué'),
              _Legend(color: Color(0xFFEF4444), label: 'Faible'),
              _Legend(color: Color(0xFFF59E0B), label: 'Moyenne'),
              _Legend(color: Color(0xFF10B981), label: 'Bonne+'),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: SM.b(11, color: SM.muted)),
      ],
    );
  }
}
