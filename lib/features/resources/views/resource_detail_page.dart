import 'package:flutter/material.dart';
import '../../../core/widgets/gemini_key_dialog.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/pdf_storage.dart';
import '../../../core/widgets/sm_widgets.dart';
import '../../../core/widgets/resource_scope.dart';
import '../models/resource.dart';
import '../services/ai_resource_service.dart';

class ResourceDetailPage extends StatefulWidget {
  final int id;
  const ResourceDetailPage({super.key, required this.id});

  @override
  State<ResourceDetailPage> createState() => _ResourceDetailPageState();
}

class _ResourceDetailPageState extends State<ResourceDetailPage> {
  String? panel;
  int cardIndex = 0;
  bool showAnswer = false;
  bool aiBusy = false;

  Future<bool> _ensureGeminiKey() => ensureGeminiKey(
        context,
        reason: 'Le résumé et les flashcards sont générés par Gemini. Collez votre clé (Google AI Studio).',
      );

  Future<void> _summary(Resource r) async {
    final vm = ResourceScope.of(context);
    if (!await _ensureGeminiKey()) return;
    setState(() => aiBusy = true);
    try {
      await vm.summarize(r);
      if (!mounted) return;
      setState(() => panel = 'Résumé');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AiException ? e.message : 'Erreur Gemini : $e')),
      );
    } finally {
      if (mounted) setState(() => aiBusy = false);
    }
  }

  Future<void> _flashcards(Resource r) async {
    final vm = ResourceScope.of(context);
    if (!await _ensureGeminiKey()) return;
    setState(() => aiBusy = true);
    try {
      await vm.generateFlashcards(r);
      if (!mounted) return;
      setState(() {
        panel = 'Flashcards';
        cardIndex = 0;
        showAnswer = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AiException ? e.message : 'Erreur Gemini : $e')),
      );
    } finally {
      if (mounted) setState(() => aiBusy = false);
    }
  }

  Future<void> _openFile(Resource r) async {
    final error = await PdfStorage.open(
      name: r.pdfName ?? 'cours',
      path: r.pdfPath,
      bytes: r.pdfBytes,
      mime: r.attachedMimeType,
    );
    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _delete(Resource r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ?', style: SM.h(20)),
        content: Text('« ${r.title} » sera retirée définitivement.', style: SM.b(15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ResourceScope.of(context).remove(r.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ResourceScope.of(context);
    final r = vm.byId(widget.id);
    if (r == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: SM.bg),
        body: const Center(child: Text('Ressource introuvable')),
      );
    }
    if (!vm.canView(r)) {
      return Scaffold(
        appBar: AppBar(backgroundColor: SM.bg),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline, size: 48, color: SM.muted),
              const SizedBox(height: 16),
              Text('Accès réservé', style: SM.h(18), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                r.visibility == ResourceVisibility.group
                    ? 'Cette ressource est réservée aux membres du groupe${r.groupName == null ? '' : ' « ${r.groupName} »'}.'
                    : 'Cette ressource est privée.',
                style: SM.b(14, color: SM.muted),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ),
      );
    }
    final cards = vm.flashcards.where((c) => c.resourceId == r.id).toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: SM.bg,
        title: Text(r.subject, style: SM.h(17)),
        actions: [
          IconButton(
            tooltip: r.isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
            icon: Icon(
              r.isFavorite ? Icons.favorite : Icons.favorite_border,
              size: 22,
              color: r.isFavorite ? SM.danger : SM.muted,
            ),
            onPressed: () => vm.toggleFavorite(r),
          ),
          if (r.canManage)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => Navigator.pushNamed(context, AppRoutes.resourceForm, arguments: r),
            ),
          if (r.canManage)
            IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: SM.danger), onPressed: () => _delete(r)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(r.title, style: SM.h(24)),
        const SizedBox(height: 6),
        Text('Par ${r.author} · ${r.pages} pages', style: SM.b(14, color: SM.muted)),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          SMBadge(r.priceLabel, kind: r.isFree ? BadgeKind.free : BadgeKind.paid),
          SMBadge(r.visibilityLabel),
          if (r.hasFile) SMBadge(r.attachedLabel),
        ]),
        if (r.hasFile) ...[
          const SizedBox(height: 16),
          SMCard(
            onTap: () => _openFile(r),
            child: Row(children: [
              Icon(
                r.attachedKind == ResourceFileKind.powerpoint
                    ? Icons.slideshow
                    : Icons.picture_as_pdf,
                color: r.attachedKind == ResourceFileKind.powerpoint ? SM.accent : SM.danger,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.pdfName!, style: SM.b(15, w: FontWeight.w600)),
                  Text('Ouvrir le cours', style: SM.b(13, color: SM.muted)),
                ]),
              ),
              const Icon(Icons.open_in_new, size: 18, color: SM.muted),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        Text(r.content, style: SM.b(15)),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _aiButton('Résumé', Icons.auto_awesome, () => _summary(r))),
          const SizedBox(width: 12),
          Expanded(child: _aiButton('Flashcards', Icons.layers, () => _flashcards(r))),
        ]),
        if (aiBusy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: SM.anim,
          child: panel == null
              ? const SizedBox.shrink()
              : SMCard(
                  key: ValueKey('$panel-$cardIndex-$showAnswer'),
                  color: SM.aiSoft,
                  child: panel == 'Résumé'
                      ? Text(
                          r.summary ?? 'Aucun résumé pour le moment. Touchez Résumé pour le générer avec Gemini.',
                          style: SM.b(15),
                        )
                      : _flashcardPanel(cards),
                ),
        ),
      ]),
    );
  }

  Widget _flashcardPanel(List<Flashcard> cards) {
    if (cards.isEmpty) {
      return Text('Aucune flashcard. Touchez Flashcards pour les générer avec Gemini.', style: SM.b(15));
    }
    final c = cards[cardIndex.clamp(0, cards.length - 1)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Flashcard ${cardIndex + 1}/${cards.length}', style: SM.b(13, color: SM.ai, w: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(c.question, style: SM.b(16, w: FontWeight.w600)),
      const SizedBox(height: 10),
      Text(showAnswer ? c.answer : 'Touchez pour voir la réponse.', style: SM.b(15)),
      const SizedBox(height: 12),
      Row(children: [
        OutlinedButton(
          onPressed: () => setState(() => showAnswer = !showAnswer),
          child: Text(showAnswer ? 'Masquer' : 'Réponse'),
        ),
        const Spacer(),
        IconButton(
          onPressed: cardIndex == 0 ? null : () => setState(() { cardIndex--; showAnswer = false; }),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: cardIndex >= cards.length - 1 ? null : () => setState(() { cardIndex++; showAnswer = false; }),
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
    ]);
  }

  Widget _aiButton(String label, IconData icon, VoidCallback onPressed) => ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: SM.aiSoft, foregroundColor: SM.ai),
        onPressed: aiBusy ? null : onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
}
