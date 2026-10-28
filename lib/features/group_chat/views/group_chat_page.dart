import 'dart:io' as dart_io;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/chat_message.dart';
import '../viewmodels/group_chat_viewmodel.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_input_bar.dart';

/// Main group chat screen.
class GroupChatPage extends StatefulWidget {
  final GroupChatViewModel viewModel;

  const GroupChatPage({super.key, required this.viewModel});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  bool _atBottom = true;

  // Keys and highlight state shared with _MessageList
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  GroupChatViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _vm.addListener(_onVmUpdate);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _vm.removeListener(_onVmUpdate);
    _scrollController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;

    // Load older messages when scrolled to top
    if (pos.pixels <= 60 && _vm.hasMore) {
      _vm.loadMoreMessages();
    }

    final atBottom = pos.pixels >= pos.maxScrollExtent - 80;
    if (atBottom != _atBottom) setState(() => _atBottom = atBottom);
  }

  void _onVmUpdate() {
    // Auto-scroll to bottom when a new message arrives and we're at the bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_atBottom && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Scrolls to and highlights the message with [messageId], like WhatsApp.
  Future<void> _scrollToMessage(String messageId) async {
    final messages = _vm.messages;
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index < 0) return;

    // Estimate scroll offset: ~72px per bubble + 8px top padding
    const double approxItemHeight = 72.0;
    final double targetOffset =
        (index * approxItemHeight).clamp(0.0, _scrollController.position.maxScrollExtent);

    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );

    // Wait one frame so the item is visible and its key is attached
    await Future.delayed(const Duration(milliseconds: 50));

    // Try Scrollable.ensureVisible now that the item is rendered
    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }

    // Flash highlight
    if (mounted) {
      setState(() => _highlightedMessageId = messageId);
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _highlightedMessageId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        return Scaffold(
          appBar: _buildAppBar(context),
          body: Column(
            children: [
              // Pinned message banner
              if (_vm.pinnedMessages.isNotEmpty)
                _PinnedBanner(
                  message: _vm.pinnedMessages.first,
                  viewModel: _vm,
                  onTap: () => _navigateToPinned(context),
                ),

              // Error message
              if (_vm.errorMessage != null)
                _ErrorBanner(
                  message: _vm.errorMessage!,
                  onDismiss: _vm.clearError,
                ),

              // Search results overlay
              if (_vm.isSearching)
                Expanded(child: _SearchResultsView(viewModel: _vm))
              else
                Expanded(
                  child: _vm.isLoading && _vm.messages.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _vm.messages.isEmpty
                          ? _EmptyChat(groupName: _vm.groupName)
                          : _MessageList(
                              messages: _vm.messages,
                              viewModel: _vm,
                              scrollController: _scrollController,
                              messageKeys: _messageKeys,
                              highlightedMessageId: _highlightedMessageId,
                              onScrollToMessage: _scrollToMessage,
                            ),
                ),

              // Scroll-to-bottom FAB area
              if (!_atBottom && !_vm.isSearching)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 4),
                    child: FloatingActionButton.small(
                      heroTag: 'scroll_bottom',
                      onPressed: _scrollToBottom,
                      child: const Icon(Icons.arrow_downward, size: 18),
                    ),
                  ),
                ),

              // Input bar (hidden during search)
              if (!_vm.isSearching)
                ChatInputBar(
                  viewModel: _vm,
                  controller: _textController,
                  focusNode: _focusNode,
                ),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.groups_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _vm.groupName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_vm.memberCount} membre${_vm.memberCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _vm.isSearching ? Icons.close : Icons.search,
            color: AppColors.text,
          ),
          tooltip: _vm.isSearching ? 'Fermer' : 'Rechercher',
          onPressed: _vm.toggleSearch,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.text),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onSelected: (v) {
            switch (v) {
              case 'photos':
                _navigateToPhotos(context);
                break;
              case 'documents':
                _navigateToDocuments(context);
                break;
              case 'pinned':
                _navigateToPinned(context);
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'photos',
                child: ListTile(
                  leading: Icon(Icons.photo_library_outlined,
                      color: AppColors.primary),
                  title: Text('Voir les photos'),
                  contentPadding: EdgeInsets.zero,
                )),
            PopupMenuItem(
                value: 'documents',
                child: ListTile(
                  leading:
                      Icon(Icons.folder_outlined, color: AppColors.primary),
                  title: Text('Voir les documents'),
                  contentPadding: EdgeInsets.zero,
                )),
            PopupMenuItem(
                value: 'pinned',
                child: ListTile(
                  leading:
                      Icon(Icons.push_pin_outlined, color: AppColors.primary),
                  title: Text('Messages épinglés'),
                  contentPadding: EdgeInsets.zero,
                )),
          ],
        ),
      ],
    );
  }

  void _navigateToPinned(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PinnedMessagesPage(viewModel: _vm),
    ));
  }

  void _navigateToPhotos(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MediaGalleryPage(viewModel: _vm, initialTab: 0),
    ));
  }

  void _navigateToDocuments(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MediaGalleryPage(viewModel: _vm, initialTab: 1),
    ));
  }
}

// ─── Message List ────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final GroupChatViewModel viewModel;
  final ScrollController scrollController;
  final Map<String, GlobalKey> messageKeys;
  final String? highlightedMessageId;
  final Future<void> Function(String messageId) onScrollToMessage;

  const _MessageList({
    required this.messages,
    required this.viewModel,
    required this.scrollController,
    required this.messageKeys,
    required this.highlightedMessageId,
    required this.onScrollToMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final msg = messages[i];
        final prev = i > 0 ? messages[i - 1] : null;

        // Ensure each message has a stable GlobalKey
        final key = messageKeys.putIfAbsent(msg.id, () => GlobalKey());

        // Date separator
        final showDateSep =
            prev == null || !_sameDay(prev.createdAt, msg.createdAt);

        // Group consecutive messages from same sender
        final showSenderInfo = prev == null ||
            prev.senderId != msg.senderId ||
            showDateSep ||
            msg.createdAt.difference(prev.createdAt).inMinutes > 5;

        final isHighlighted = highlightedMessageId == msg.id;

        return Column(
          key: key,
          children: [
            if (showDateSep) _DateSeparator(date: msg.createdAt),
            _HighlightWrapper(
              highlighted: isHighlighted,
              child: ChatMessageBubble(
                message: msg,
                viewModel: viewModel,
                showSenderInfo: showSenderInfo,
                onReplyTap: msg.replyToMessageId != null
                    ? () => onScrollToMessage(msg.replyToMessageId!)
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─── Highlight flash wrapper ──────────────────────────────────────────────────

class _HighlightWrapper extends StatefulWidget {
  final bool highlighted;
  final Widget child;
  const _HighlightWrapper({required this.highlighted, required this.child});

  @override
  State<_HighlightWrapper> createState() => _HighlightWrapperState();
}

class _HighlightWrapperState extends State<_HighlightWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _colorAnim = ColorTween(
      begin: const Color(0xFFFFEB3B).withValues(alpha: 0.45),
      end: Colors.transparent,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_HighlightWrapper old) {
    super.didUpdateWidget(old);
    if (widget.highlighted && !old.highlighted) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Container(
        color: widget.highlighted ? _colorAnim.value : Colors.transparent,
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _label(date),
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  String _label(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return "Aujourd'hui";
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Hier';
    }
    final months = [
      '', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }
}

// ─── Pinned banner ────────────────────────────────────────────────────────────

class _PinnedBanner extends StatelessWidget {
  final ChatMessage message;
  final GroupChatViewModel viewModel;
  final VoidCallback onTap;

  const _PinnedBanner({
    required this.message,
    required this.viewModel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: AppColors.primarySoft,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.push_pin, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Message épinglé',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                  Text(
                    message.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (viewModel.pinnedMessages.length > 1)
              Text(
                '+${viewModel.pinnedMessages.length - 1}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final String groupName;
  const _EmptyChat({required this.groupName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Discussion de $groupName',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Soyez le premier à écrire un message !',
              style: TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error banner ────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.danger.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ─── Search results ──────────────────────────────────────────────────────────

class _SearchResultsView extends StatefulWidget {
  final GroupChatViewModel viewModel;
  const _SearchResultsView({required this.viewModel});

  @override
  State<_SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends State<_SearchResultsView> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Rechercher dans la discussion…',
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.muted),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppColors.muted, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        vm.search('');
                      },
                    )
                  : null,
            ),
            onChanged: vm.search,
          ),
        ),
        Expanded(
          child: vm.searchQuery.isEmpty
              ? const Center(
                  child: Text('Tapez pour rechercher…',
                      style: TextStyle(color: AppColors.muted)))
              : vm.searchResults.isEmpty
                  ? const Center(
                      child: Text('Aucun résultat.',
                          style: TextStyle(color: AppColors.muted)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: vm.searchResults.length,
                      separatorBuilder: (_, idx) =>
                          const Divider(height: 1, color: AppColors.primarySoft),
                      itemBuilder: (_, i) {
                        final msg = vm.searchResults[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primarySoft,
                            child: Text(
                              msg.senderName.isNotEmpty
                                  ? msg.senderName[0]
                                  : '?',
                              style: const TextStyle(color: AppColors.primary),
                            ),
                          ),
                          title: Text(msg.senderName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.text)),
                          subtitle: Text(
                            msg.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.muted),
                          ),
                          trailing: Text(
                            _fmtDate(msg.createdAt),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

// ─── Pinned messages page ─────────────────────────────────────────────────────

class PinnedMessagesPage extends StatelessWidget {
  final GroupChatViewModel viewModel;
  const PinnedMessagesPage({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages épinglés'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          final pinned = viewModel.pinnedMessages;
          if (pinned.isEmpty) {
            return const Center(
              child: Text('Aucun message épinglé.',
                  style: TextStyle(color: AppColors.muted)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: pinned.length,
            separatorBuilder: (_, idx) =>
                const Divider(height: 1, color: AppColors.primarySoft),
            itemBuilder: (_, i) {
              final msg = pinned[i];
              return ListTile(
                leading: const Icon(Icons.push_pin,
                    color: AppColors.primary, size: 20),
                title: Text(msg.senderName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.text)),
                subtitle: Text(
                  msg.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
                trailing: viewModel.isOwner
                    ? IconButton(
                        icon: const Icon(Icons.push_pin_outlined,
                            color: AppColors.danger, size: 20),
                        tooltip: 'Désépingler',
                        onPressed: () =>
                            viewModel.unpinMessage(msg.id),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Media Gallery Page (Photos + Documents) ───────────────────────────────

class MediaGalleryPage extends StatefulWidget {
  final GroupChatViewModel viewModel;
  final int initialTab;

  const MediaGalleryPage({
    super.key,
    required this.viewModel,
    this.initialTab = 0,
  });

  @override
  State<MediaGalleryPage> createState() => _MediaGalleryPageState();
}

class _MediaGalleryPageState extends State<MediaGalleryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<Map<String, dynamic>> _allFiles = [];
  bool _loading = true;

  List<Map<String, dynamic>> get _photos => _allFiles
      .where((f) => (f['mime_type'] as String? ?? '').startsWith('image/'))
      .toList();

  List<Map<String, dynamic>> get _documents => _allFiles
      .where((f) => !(f['mime_type'] as String? ?? '').startsWith('image/'))
      .toList();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadFiles();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    final files = await widget.viewModel.getSharedFiles();
    if (mounted) {
      setState(() {
        _allFiles = files;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Médias partagés',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text)),
            Text(widget.viewModel.groupName,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              text:
                  'Photos (${_loading ? '…' : _photos.length.toString()})',
            ),
            Tab(
              icon:
                  const Icon(Icons.description_outlined, size: 20),
              text:
                  'Documents (${_loading ? '…' : _documents.length.toString()})',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _PhotosGrid(
                    photos: _photos, viewModel: widget.viewModel),
                _DocumentsList(
                    documents: _documents,
                    viewModel: widget.viewModel),
              ],
            ),
    );
  }
}

// ─── Photos grid ────────────────────────────────────────────────────────────

class _PhotosGrid extends StatelessWidget {
  final List<Map<String, dynamic>> photos;
  final GroupChatViewModel viewModel;
  const _PhotosGrid({required this.photos, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.photo_library_outlined,
              size: 56, color: AppColors.muted),
          SizedBox(height: 12),
          Text('Aucune photo partagée.',
              style: TextStyle(color: AppColors.muted, fontSize: 15)),
        ]),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(3),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
      ),
      itemCount: photos.length,
      itemBuilder: (ctx, i) => GestureDetector(
        onTap: () => Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => _FullscreenGallery(
              photos: photos, startIndex: i, viewModel: viewModel),
        )),
        child: _PhotoThumbnail(
            localPath: photos[i]['local_path'] as String? ?? '',
            viewModel: viewModel),
      ),
    );
  }
}

class _PhotoThumbnail extends StatefulWidget {
  final String localPath;
  final GroupChatViewModel viewModel;
  const _PhotoThumbnail(
      {required this.localPath, required this.viewModel});

  @override
  State<_PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<_PhotoThumbnail> {
  String? _absPath;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final p =
        await widget.viewModel.resolveAttachmentPath(widget.localPath);
    if (mounted) setState(() => _absPath = p);
  }

  @override
  Widget build(BuildContext context) {
    if (_absPath == null) {
      return Container(
          color: Colors.grey.shade100,
          child: const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)));
    }
    return Image.file(
      dart_io.File(_absPath!),
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, st) => Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.muted, size: 32),
      ),
    );
  }
}

// ─── Fullscreen photo viewer ────────────────────────────────────────────────

class _FullscreenGallery extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int startIndex;
  final GroupChatViewModel viewModel;
  const _FullscreenGallery(
      {required this.photos,
      required this.startIndex,
      required this.viewModel});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.startIndex;
    _pageCtrl = PageController(initialPage: widget.startIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.photos[_current];
    final sender = f['sender_name'] as String? ?? '?';
    final sentAt = f['sent_at'] as String? ?? '';
    final date = sentAt.isNotEmpty ? DateTime.tryParse(sentAt) : null;
    final fname = f['original_filename'] as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fname.isNotEmpty ? fname : sender,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            Text(
              date != null
                  ? '$sender  ·  ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                  : sender,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${_current + 1}/${widget.photos.length}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, i) => _FullscreenPhoto(
            localPath:
                widget.photos[i]['local_path'] as String? ?? '',
            viewModel: widget.viewModel),
      ),
    );
  }
}

class _FullscreenPhoto extends StatefulWidget {
  final String localPath;
  final GroupChatViewModel viewModel;
  const _FullscreenPhoto(
      {required this.localPath, required this.viewModel});

  @override
  State<_FullscreenPhoto> createState() => _FullscreenPhotoState();
}

class _FullscreenPhotoState extends State<_FullscreenPhoto> {
  String? _absPath;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final p =
        await widget.viewModel.resolveAttachmentPath(widget.localPath);
    if (mounted) setState(() => _absPath = p);
  }

  @override
  Widget build(BuildContext context) {
    if (_absPath == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          dart_io.File(_absPath!),
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, st) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64),
        ),
      ),
    );
  }
}

// ─── Documents list ────────────────────────────────────────────────────────────

class _DocumentsList extends StatelessWidget {
  final List<Map<String, dynamic>> documents;
  final GroupChatViewModel viewModel;
  const _DocumentsList(
      {required this.documents, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.description_outlined,
              size: 56, color: AppColors.muted),
          SizedBox(height: 12),
          Text('Aucun document partagé.',
              style: TextStyle(color: AppColors.muted, fontSize: 15)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: documents.length,
      separatorBuilder: (_, i) => const Divider(
          height: 1, indent: 72, color: AppColors.primarySoft),
      itemBuilder: (context, i) {
        final f = documents[i];
        final filename = f['original_filename'] as String? ?? '';
        final mime =
            f['mime_type'] as String? ?? 'application/octet-stream';
        final size = f['file_size'] as int? ?? 0;
        final sender = f['sender_name'] as String? ?? '?';
        final sentAt = f['sent_at'] as String? ?? '';
        final date =
            sentAt.isNotEmpty ? DateTime.tryParse(sentAt) : null;
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_docIcon(mime),
                color: AppColors.primary, size: 24),
          ),
          title: Text(filename,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$sender  ·  ${_fmtSize(size)}${date != null ? '  ·  ${_fmtDate(date)}' : ''}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.muted),
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.open_in_new,
                color: AppColors.primary, size: 20),
            tooltip: 'Ouvrir',
            onPressed: () => viewModel.openAttachment(ChatAttachment(
              id: f['id'] as String? ?? '',
              messageId: f['message_id'] as String? ?? '',
              originalFilename: filename,
              localPath: f['local_path'] as String? ?? '',
              mimeType: mime,
              fileSize: size,
              createdAt: date ?? DateTime.now(),
            )),
          ),
          onTap: () => viewModel.openAttachment(ChatAttachment(
            id: f['id'] as String? ?? '',
            messageId: f['message_id'] as String? ?? '',
            originalFilename: filename,
            localPath: f['local_path'] as String? ?? '',
            mimeType: mime,
            fileSize: size,
            createdAt: date ?? DateTime.now(),
          )),
        );
      },
    );
  }

  IconData _docIcon(String mime) {
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.contains('word')) return Icons.article_outlined;
    if (mime.contains('sheet') || mime.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    if (mime.contains('presentation') || mime.contains('powerpoint')) {
      return Icons.slideshow_outlined;
    }
    if (mime == 'text/plain') return Icons.text_snippet_outlined;
    return Icons.attach_file;
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
