import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/session_user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../group_chat/repositories/group_chat_repository.dart';
import '../models/book.dart';
import '../viewmodels/book_suggestions_viewmodel.dart';

/// Section « Livres recommandés » de la page d'un groupe.
///
/// API externe : Google Books (sans clé). La recherche est construite à partir
/// du sujet du groupe ; l'utilisateur peut l'affiner. Un membre peut partager
/// un livre dans le chat du groupe.
class GroupBooksSection extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupDescription;
  final bool isMember;

  const GroupBooksSection({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.groupDescription,
    required this.isMember,
  });

  @override
  State<GroupBooksSection> createState() => _GroupBooksSectionState();
}

class _GroupBooksSectionState extends State<GroupBooksSection> {
  late final BookSuggestionsViewModel _vm = BookSuggestionsViewModel(
    groupName: widget.groupName,
    groupDescription: widget.groupDescription,
  );
  final _searchCtrl = TextEditingController();
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _vm.loadInitial();
  }

  @override
  void dispose() {
    _vm.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _submitSearch() {
    FocusScope.of(context).unfocus();
    _vm.search(_searchCtrl.text);
  }

  void _resetSearch() {
    _searchCtrl.clear();
    setState(() => _searchOpen = false);
    _vm.search('', fallbackToDescription: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Livres recommandés',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text),
                  ),
                ),
                IconButton(
                  tooltip: _searchOpen ? 'Fermer la recherche' : 'Rechercher un sujet',
                  icon: Icon(_searchOpen ? Icons.close : Icons.search, size: 20),
                  onPressed: () => _searchOpen ? _resetSearch() : setState(() => _searchOpen = true),
                ),
              ],
            ),
            Text(
              'Sujet : « ${_vm.query} » · via ${_vm.source}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            if (_searchOpen) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submitSearch(),
                decoration: InputDecoration(
                  hintText: 'Ex. Spring Security, Docker, algorithmes…',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _submitSearch,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _content(context),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (_vm.isLoading) {
      return const SizedBox(height: 190, child: Center(child: CircularProgressIndicator()));
    }
    if (_vm.error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_vm.error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          TextButton.icon(
            onPressed: _vm.retry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Réessayer'),
          ),
        ],
      );
    }
    if (_vm.books.isEmpty) {
      return const Text(
        'Aucun livre trouvé pour ce sujet. Essayez d\'autres mots-clés avec la loupe.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      );
    }
    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _vm.books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _BookCard(
          book: _vm.books[i],
          onTap: () => _openDetails(context, _vm.books[i]),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, Book book) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.rCard)),
      ),
      builder: (_) => _BookDetailsSheet(
        book: book,
        canShare: widget.isMember,
        groupId: widget.groupId,
      ),
    );
  }
}

// ─── Carte d'un livre ────────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const _BookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cover(url: book.thumbnailUrl, width: 112, height: 150),
            const SizedBox(height: 6),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
            Text(
              [book.authorsLabel, if (book.year != null) book.year!].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String? url;
  final double width;
  final double height;

  const _Cover({required this.url, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: const Icon(Icons.menu_book, color: AppColors.primary, size: 36),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
            ),
    );
  }
}

// ─── Détail d'un livre ───────────────────────────────────────────────────────

class _BookDetailsSheet extends StatefulWidget {
  final Book book;
  final bool canShare;
  final String groupId;

  const _BookDetailsSheet({required this.book, required this.canShare, required this.groupId});

  @override
  State<_BookDetailsSheet> createState() => _BookDetailsSheetState();
}

class _BookDetailsSheetState extends State<_BookDetailsSheet> {
  bool _sharing = false;

  Future<void> _openLink() async {
    final link = widget.book.infoLink;
    final messenger = ScaffoldMessenger.of(context);
    final uri = link == null ? null : Uri.tryParse(link);
    final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir le lien.')));
    }
  }

  Future<void> _shareInChat() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sharing = true);
    try {
      final msg = await GroupChatRepository().sendMessage(
        groupId: widget.groupId,
        senderId: SessionUser.uid,
        content: BookSuggestionsViewModel.chatMessageFor(widget.book),
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text(msg == null
            ? 'Vous devez être membre du groupe pour partager.'
            : 'Livre partagé dans la discussion du groupe.'),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sharing = false);
      messenger.showSnackBar(const SnackBar(content: Text('Partage impossible. Réessayez.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final details = [
      if (book.year != null) book.year!,
      if (book.pageCount != null && book.pageCount! > 0) '${book.pageCount} pages',
      if (book.language != null) book.language!.toUpperCase(),
    ].join(' · ');

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Cover(url: book.thumbnailUrl, width: 90, height: 130),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                        const SizedBox(height: 4),
                        Text(book.authorsLabel, style: const TextStyle(color: AppColors.muted)),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(details, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                        const SizedBox(height: 8),
                        if (book.isFreeToRead)
                          const AppBadge('Lecture gratuite', type: AppBadgeType.success)
                        else if (book.hasPreview)
                          const AppBadge('Aperçu disponible', type: AppBadgeType.primary),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                book.description?.isNotEmpty == true ? book.description! : 'Pas de résumé disponible.',
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.text),
              ),
              const SizedBox(height: 18),
              if (book.infoLink != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openLink,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text('Voir sur ${book.source}'),
                  ),
                ),
              if (widget.canShare) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sharing ? null : _shareInChat,
                    icon: _sharing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Partager dans le chat'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
