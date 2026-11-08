import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/session_user.dart';
import '../../../core/constants/groups.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/pdf_storage.dart';
import '../../../core/widgets/sm_widgets.dart';
import '../../../core/widgets/resource_scope.dart';
import '../models/resource.dart';

class ResourceFormPage extends StatefulWidget {
  final Resource? existing;
  const ResourceFormPage({super.key, this.existing});

  @override
  State<ResourceFormPage> createState() => _ResourceFormPageState();
}

class _ResourceFormPageState extends State<ResourceFormPage> {
  late final title = TextEditingController(text: widget.existing?.title ?? '');
  late final subject = TextEditingController(text: widget.existing?.subject ?? '');
  late final content = TextEditingController(text: widget.existing?.content ?? '');
  late final pages = TextEditingController(text: '${widget.existing?.pages ?? 10}');
  late final price = TextEditingController(
      text: widget.existing == null || widget.existing!.isFree ? '10' : widget.existing!.price.toStringAsFixed(0));

  late ResourceVisibility visibility = widget.existing?.visibility ?? ResourceVisibility.public;
  late bool isFree = widget.existing?.isFree ?? true;
  late String? groupId = widget.existing?.groupId ?? groups.first.id;
  late String? pdfPath = widget.existing?.pdfPath;
  late String? pdfName = widget.existing?.pdfName;
  late Uint8List? pdfBytes = widget.existing?.pdfBytes;
  String? _previousPdfPath;

  bool get hasFile => pdfName != null && pdfName!.isNotEmpty;

  ResourceFileKind get attachedKind => ResourceFileKind.fromName(pdfName);

  @override
  void dispose() {
    title.dispose();
    subject.dispose();
    content.dispose();
    pages.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: PdfStorage.allowedExtensions,
      );
      if (files.isEmpty) return;
      final saved = await PdfStorage.save(files.first);
      if (saved == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de joindre ce fichier. PDF ou PowerPoint uniquement.')),
        );
        return;
      }
      if (pdfPath != null && pdfPath != widget.existing?.pdfPath) {
        await PdfStorage.delete(pdfPath);
      } else {
        _previousPdfPath ??= widget.existing?.pdfPath;
      }
      setState(() {
        pdfPath = saved.path;
        pdfName = saved.name;
        pdfBytes = saved.bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sélection du fichier impossible : $e')),
      );
    }
  }

  void _removePdf() {
    setState(() {
      if (pdfPath != widget.existing?.pdfPath) {
        PdfStorage.delete(pdfPath);
      } else {
        _previousPdfPath ??= pdfPath;
      }
      pdfPath = null;
      pdfName = null;
      pdfBytes = null;
    });
  }

  Future<void> _save() async {
    final vm = ResourceScope.of(context);
    final hasFile = pdfName != null && pdfName!.isNotEmpty;
    if (title.text.trim().length < 3 ||
        subject.text.trim().isEmpty ||
        (!hasFile && content.text.trim().length < 10)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Titre, matière et contenu (10 caractères min.) ou un fichier PDF/PowerPoint sont requis.'),
        ),
      );
      return;
    }
    Group? group;
    for (final g in groups) {
      if (g.id == groupId) group = g;
    }
    final resource = Resource(
      id: widget.existing?.id,
      title: title.text.trim(),
      subject: subject.text.trim(),
      author: widget.existing?.author ?? SessionUser.displayName,
      ownerName: widget.existing?.ownerName ?? SessionUser.email,
      content: content.text.trim().isEmpty && hasFile
          ? 'Document ${attachedKind.label} : $pdfName'
          : content.text.trim(),
      visibility: visibility,
      groupId: visibility == ResourceVisibility.group ? group?.id : null,
      groupName: visibility == ResourceVisibility.group ? group?.name : null,
      isFree: isFree,
      price: isFree ? 0 : double.tryParse(price.text.replaceAll(',', '.')) ?? 0,
      pages: int.tryParse(pages.text) ?? 1,
      summary: widget.existing?.summary,
      pdfPath: pdfPath,
      pdfName: pdfName,
      pdfBytes: kIsWeb ? pdfBytes : null,
      createdAt: widget.existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      isFavorite: widget.existing?.isFavorite ?? false,
    );
    if (_previousPdfPath != null && _previousPdfPath != pdfPath) {
      await PdfStorage.delete(_previousPdfPath);
    }
    await vm.save(resource);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!SessionUser.isTeacher) {
      return Scaffold(
        appBar: AppBar(backgroundColor: SM.bg),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: SM.muted),
                const SizedBox(height: 16),
                Text('Accès réservé aux enseignants', style: SM.h(18), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Seuls les enseignants peuvent ajouter ou modifier des ressources.',
                  style: SM.b(14, color: SM.muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: SM.bg,
        title: Text(editing ? 'Modifier la ressource' : 'Nouvelle ressource', style: SM.h(17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre')),
          const SizedBox(height: 12),
          TextField(controller: subject, decoration: const InputDecoration(labelText: 'Matière')),
          const SizedBox(height: 12),
          TextField(controller: pages, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nombre de pages')),
          const SizedBox(height: 16),
          Text('Visibilité', style: SM.b(14, w: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SMChip('Public', selected: visibility == ResourceVisibility.public, onTap: () => setState(() => visibility = ResourceVisibility.public)),
            SMChip('Privée', selected: visibility == ResourceVisibility.private, onTap: () => setState(() => visibility = ResourceVisibility.private)),
            SMChip('Groupe', selected: visibility == ResourceVisibility.group, onTap: () => setState(() => visibility = ResourceVisibility.group)),
          ]),
          if (visibility == ResourceVisibility.group) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: groupId,
              decoration: const InputDecoration(labelText: 'Partager avec'),
              items: [
                for (final g in groups) DropdownMenuItem(value: g.id, child: Text(g.name)),
              ],
              onChanged: (v) => setState(() => groupId = v),
            ),
          ],
          const SizedBox(height: 16),
          Text('Prix', style: SM.b(14, w: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            SMChip('Gratuit', selected: isFree, onTap: () => setState(() => isFree = true)),
            SMChip('Payant', selected: !isFree, onTap: () => setState(() => isFree = false)),
          ]),
          if (!isFree) ...[
            const SizedBox(height: 12),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix (DT)')),
          ],
          const SizedBox(height: 16),
          Text('Cours (PDF ou PowerPoint)', style: SM.b(14, w: FontWeight.w600)),
          const SizedBox(height: 8),
          if (pdfName != null)
            SMCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(
                  attachedKind == ResourceFileKind.powerpoint
                      ? Icons.slideshow
                      : Icons.picture_as_pdf,
                  color: attachedKind == ResourceFileKind.powerpoint ? SM.accent : SM.danger,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(pdfName!, style: SM.b(14, w: FontWeight.w600))),
                IconButton(
                  tooltip: 'Retirer le fichier',
                  onPressed: _removePdf,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ]),
            )
          else
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Joindre un PDF ou PowerPoint'),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: content,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: hasFile ? 'Description (optionnelle)' : 'Contenu du document',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _save, child: Text(editing ? 'Enregistrer' : 'Créer')),
        ],
      ),
    );
  }
}
