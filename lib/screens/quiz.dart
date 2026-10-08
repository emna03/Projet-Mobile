import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../data/mock.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class QuizCreateScreen extends StatefulWidget {
  const QuizCreateScreen({super.key});
  @override
  State<QuizCreateScreen> createState() => _QuizCreateScreenState();
}

class _QuizCreateScreenState extends State<QuizCreateScreen> {
  String resource = resources[1].id;
  String difficulty = 'Moyen';
  double count = 4;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: SM.bg, title: Text('Quiz IA', style: SM.h(17))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Row(children: [
            const Icon(LucideIcons.sparkles, color: SM.ai),
            const SizedBox(width: 8),
            Text('Créer un quiz avec l\'IA', style: SM.h(20)),
          ]),
          const SizedBox(height: 20),
          Text('Ressource', style: SM.b(14, w: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final r in resources)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SMCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onTap: () => setState(() => resource = r.id),
                child: Row(children: [
                  Icon(resource == r.id ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: resource == r.id ? SM.primary : SM.muted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.title, style: SM.b(15))),
                ]),
              ),
            ),
          const SizedBox(height: 12),
          Text('Difficulté', style: SM.b(14, w: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            for (final d in ['Facile', 'Moyen', 'Difficile'])
              Padding(padding: const EdgeInsets.only(right: 8),
                  child: SMChip(d, selected: difficulty == d, onTap: () => setState(() => difficulty = d))),
          ]),
          const SizedBox(height: 20),
          Text('Nombre de questions : ${count.round()}', style: SM.b(14, w: FontWeight.w600)),
          Slider(value: count, min: 2, max: 4, divisions: 2, activeColor: SM.primary, onChanged: (v) => setState(() => count = v)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: SM.ai),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(count: count.round()))),
            icon: const Icon(LucideIcons.sparkles, size: 18),
            label: const Text('Générer le quiz'),
          ),
        ]),
      );
}

class QuizScreen extends StatefulWidget {
  final int count;
  const QuizScreen({super.key, this.count = 4});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int i = 0, score = 0;
  int? selected;
  bool validated = false;

  late final qs = questions.take(widget.count).toList();

  void _next() {
    if (!validated) {
      setState(() {
        validated = true;
        if (selected == qs[i].correct) score++;
      });
      return;
    }
    if (i + 1 >= qs.length) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Quiz terminé', style: SM.h(20)),
          content: Text('Score : $score / ${qs.length}', style: SM.b(16)),
          actions: [TextButton(onPressed: () => Navigator.of(context)..pop()..pop(), child: const Text('Terminer'))],
        ),
      );
      return;
    }
    setState(() { i++; selected = null; validated = false; });
  }

  @override
  Widget build(BuildContext context) {
    final q = qs[i];
    return Scaffold(
      appBar: AppBar(backgroundColor: SM.bg, title: Text('Question ${i + 1}/${qs.length}', style: SM.h(17))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: (i + 1) / qs.length, minHeight: 8, color: SM.primary, backgroundColor: SM.primarySoft)),
          const SizedBox(height: 20),
          SMCard(padding: const EdgeInsets.all(24), child: Text(q.text, style: SM.h(19))),
          const SizedBox(height: 16),
          for (var k = 0; k < 4; k++) ...[_answer(q, k), const SizedBox(height: 10)],
          const Spacer(),
          ElevatedButton(onPressed: selected == null ? null : _next,
              child: Text(validated ? (i + 1 >= qs.length ? 'Voir le score' : 'Question suivante') : 'Valider')),
        ]),
      ),
    );
  }

  Widget _answer(Question q, int k) {
    Color border = Colors.transparent, bg = Colors.white;
    IconData? icon;
    if (validated && k == q.correct) { border = SM.success; bg = const Color(0xFFD1FAE5); icon = LucideIcons.check; }
    else if (validated && k == selected) { border = SM.danger; bg = const Color(0xFFFEE2E2); icon = LucideIcons.x; }
    else if (k == selected) { border = SM.primary; bg = SM.primarySoft; }
    return GestureDetector(
      onTap: validated ? null : () => setState(() => selected = k),
      child: AnimatedContainer(
        duration: SM.anim,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(SM.rButton),
            border: Border.all(color: border, width: 2), boxShadow: SM.shadow),
        child: Row(children: [
          CircleAvatar(radius: 15, backgroundColor: SM.primarySoft,
              child: Text('ABCD'[k], style: SM.b(13, color: SM.primary, w: FontWeight.w700))),
          const SizedBox(width: 12),
          Expanded(child: Text(q.answers[k], style: SM.b(15))),
          if (icon != null) Icon(icon, color: border),
        ]),
      ),
    );
  }
}
