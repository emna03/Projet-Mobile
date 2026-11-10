import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../gestion_user/models/public_profile.dart';
import '../models/join_request.dart';
import '../viewmodels/group_viewmodel.dart';

/// Ouvre la liste des demandes d'adhésion reçues (tous mes groupes privés).
Future<void> showJoinRequestsSheet(BuildContext context, GroupViewModel viewModel) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.rCard)),
    ),
    builder: (_) => JoinRequestsSheet(viewModel: viewModel),
  );
}

/// Notifications de demandes d'adhésion : Accepter (le membre rejoint le
/// groupe) ou Refuser (la demande est rejetée). Mise à jour en temps réel.
class JoinRequestsSheet extends StatefulWidget {
  final GroupViewModel viewModel;
  const JoinRequestsSheet({super.key, required this.viewModel});

  @override
  State<JoinRequestsSheet> createState() => _JoinRequestsSheetState();
}

class _JoinRequestsSheetState extends State<JoinRequestsSheet> {
  final Set<String> _busy = {};

  Future<void> _decide(JoinRequest request, {required bool accept}) async {
    final messenger = ScaffoldMessenger.of(context);
    final vm = widget.viewModel;
    final groupName = vm.groupNameOf(request.groupId);
    final name = request.userName ?? 'Cet étudiant';
    setState(() => _busy.add(request.id));
    String? error;
    if (accept) {
      error = await vm.acceptRequest(request);
    } else {
      final ok = await vm.rejectRequest(request);
      if (!ok) error = 'Impossible de refuser la demande.';
    }
    if (!mounted) return;
    setState(() => _busy.remove(request.id));
    messenger.showSnackBar(SnackBar(
      backgroundColor: error == null ? AppColors.text : AppColors.danger,
      content: Text(error ??
          (accept ? '$name a rejoint « $groupName ».' : 'Demande de $name refusée.')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final requests = widget.viewModel.allPendingRequests;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Demandes d\'adhésion (${requests.length})',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                if (requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: Text(
                      'Aucune demande en attente.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: requests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _RequestTile(
                        request: requests[i],
                        groupName: widget.viewModel.groupNameOf(requests[i].groupId),
                        busy: _busy.contains(requests[i].id),
                        onAccept: () => _decide(requests[i], accept: true),
                        onReject: () => _decide(requests[i], accept: false),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final JoinRequest request;
  final String groupName;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestTile({
    required this.request,
    required this.groupName,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final name = request.userName ?? 'Étudiant';
    final initials = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppDimensions.rButton),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.avatarColors[
                    PublicProfile.colorIndexFor(request.userId) % AppColors.avatarColors.length],
                child: Text(initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const TextSpan(text: ' veut rejoindre '),
                    TextSpan(text: '« $groupName »', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  style: const TextStyle(fontSize: 14, color: AppColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(6),
                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18, color: AppColors.danger),
                    label: const Text('Refuser', style: TextStyle(color: AppColors.danger)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accepter'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
