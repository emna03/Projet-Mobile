import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../viewmodels/group_chat_viewmodel.dart';

/// Bottom composer bar: text input, attachment button, send button,
/// reply/edit indicator.
class ChatInputBar extends StatefulWidget {
  final GroupChatViewModel viewModel;
  final TextEditingController controller;
  final FocusNode focusNode;

  const ChatInputBar({
    super.key,
    required this.viewModel,
    required this.controller,
    required this.focusNode,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChange);

    // Pre-fill text when editing
    widget.viewModel.addListener(_onViewModelChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    widget.viewModel.removeListener(_onViewModelChange);
    super.dispose();
  }

  void _onTextChange() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _onViewModelChange() {
    if (widget.viewModel.isEditing &&
        widget.viewModel.editingMessage != null) {
      final content = widget.viewModel.editingMessage!.content;
      widget.controller.text = content;
      widget.controller.selection = TextSelection.collapsed(
        offset: content.length,
      );
      widget.focusNode.requestFocus();
    } else if (!widget.viewModel.isEditing &&
        widget.viewModel.replyingTo == null) {
      // Cleared compose state — do NOT clear text if user typed something
    }
  }

  Future<void> _send() async {
    final text = widget.controller.text;
    final success = await widget.viewModel.sendTextMessage(text);
    if (success) {
      widget.controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final vm = widget.viewModel;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reply / edit indicator
                if (vm.replyingTo != null)
                  _ReplyIndicator(
                    senderName: vm.replyingTo!.senderName,
                    content: vm.replyingTo!.content,
                    onClose: () => vm.setReplyTo(null),
                  )
                else if (vm.isEditing)
                  _EditIndicator(onClose: () {
                    vm.clearCompose();
                    widget.controller.clear();
                  }),

                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Attachment button
                      _AttachButton(viewModel: vm),
                      const SizedBox(width: 6),

                      // Text input
                      Expanded(
                        child: Container(
                          constraints:
                              const BoxConstraints(maxHeight: 120),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            maxLines: null,
                            minLines: 1,
                            textCapitalization:
                                TextCapitalization.sentences,
                            style: const TextStyle(
                                fontSize: 15, color: AppColors.text),
                            decoration: const InputDecoration(
                              hintText: 'Écrire un message…',
                              hintStyle: TextStyle(color: AppColors.muted),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Send button
                      AnimatedScale(
                        scale: _hasText ? 1.0 : 0.8,
                        duration: const Duration(milliseconds: 150),
                        child: GestureDetector(
                          onTap: _hasText ? _send : null,
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _hasText
                                  ? AppColors.primary
                                  : AppColors.primarySoft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              vm.isEditing ? Icons.check : Icons.send,
                              color: _hasText
                                  ? Colors.white
                                  : AppColors.muted,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttachButton extends StatelessWidget {
  final GroupChatViewModel viewModel;
  const _AttachButton({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: AppColors.primary),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, -140),
      onSelected: (value) async {
        switch (value) {
          case 'file':
            await viewModel.pickAndSendFile();
            break;
          case 'poll':
            _showPollDialog(context, viewModel);
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'file',
          child: ListTile(
            leading: Icon(Icons.attach_file, color: AppColors.primary),
            title: Text('Joindre un fichier'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'poll',
          child: ListTile(
            leading: Icon(Icons.poll_outlined, color: AppColors.primary),
            title: Text('Créer un sondage'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _showPollDialog(BuildContext context, GroupChatViewModel vm) {
    showDialog(
      context: context,
      builder: (ctx) => _PollCreationDialog(viewModel: vm),
    );
  }
}

class _PollCreationDialog extends StatefulWidget {
  final GroupChatViewModel viewModel;
  const _PollCreationDialog({required this.viewModel});

  @override
  State<_PollCreationDialog> createState() =>
      _PollCreationDialogState();
}

class _PollCreationDialogState extends State<_PollCreationDialog> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty) {
      setState(() => _error = 'Saisissez la question du sondage.');
      return;
    }
    final options = _optionCtrls
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (options.length < 2) {
      setState(() => _error = 'Ajoutez au moins 2 options.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final ok = await widget.viewModel.sendPoll(
      question: question,
      options: options,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _sending = false;
        _error = 'Erreur lors de la création du sondage.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.poll_outlined, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Créer un sondage'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Question',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 8),
            TextField(
              controller: _questionCtrl,
              decoration: InputDecoration(
                hintText: 'Ex: Quelle matière réviser vendredi ?',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const Text('Options',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 8),
            ..._optionCtrls.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: e.value,
                          decoration: InputDecoration(
                            hintText: 'Option ${e.key + 1}',
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      if (e.key >= 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppColors.danger),
                          onPressed: () => setState(
                              () => _optionCtrls.removeAt(e.key)),
                        ),
                    ],
                  ),
                )),
            if (_optionCtrls.length < 8)
              TextButton.icon(
                onPressed: () => setState(() =>
                    _optionCtrls.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une option'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _sending ? null : _submit,
          style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 40)),
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Créer'),
        ),
      ],
    );
  }
}

class _ReplyIndicator extends StatelessWidget {
  final String senderName;
  final String content;
  final VoidCallback onClose;

  const _ReplyIndicator({
    required this.senderName,
    required this.content,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primarySoft,
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(senderName,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
                Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _EditIndicator extends StatelessWidget {
  final VoidCallback onClose;
  const _EditIndicator({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.primarySoft,
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Modification du message',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
