import 'package:flutter/material.dart';
import 'package:studymate/features/meet/google_meet_api.dart';
import 'package:studymate/features/meet/meet_space.dart';
import 'package:studymate/theme/app_colors.dart';

/// Liste des personnes invitées dans une salle Meet en accès « Invitation ».
///
/// Les invités vivent chez Google : on les lit et on les modifie avec l'API
/// `spaces.members`, rien n'est copié dans la base locale.
class MeetInvitees extends StatefulWidget {
  const MeetInvitees({super.key, required this.spaceName, required this.api});

  final String spaceName;
  final GoogleMeetApi api;

  @override
  State<MeetInvitees> createState() => _MeetInviteesState();
}

class _MeetInviteesState extends State<MeetInvitees> {
  final _email = TextEditingController();
  List<MeetMember> _members = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MeetInvitees oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceName != widget.spaceName) _load();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await widget.api.listMembers(widget.spaceName);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loading = false;
      });
    } on MeetApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _add() async {
    if (_busy) return;
    final address = _email.text.trim();
    if (!isValidInviteeEmail(address)) {
      _showMessage('Saisis une adresse e-mail Google valide.');
      return;
    }
    final already = _members.any(
      (member) => member.email.toLowerCase() == address.toLowerCase(),
    );
    if (already) {
      _showMessage('Cette personne est déjà invitée.');
      return;
    }
    setState(() => _busy = true);
    try {
      final member = await widget.api.addMember(widget.spaceName, address);
      if (!mounted) return;
      setState(() {
        _members = [..._members, member];
        _error = null;
      });
      _email.clear();
    } on MeetApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(MeetMember member) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.api.removeMember(member.name);
      if (!mounted) return;
      setState(() {
        _members = _members.where((item) => item.name != member.name).toList();
      });
    } on MeetApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Text(
          'Personnes invitées',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Seules ces personnes pourront entrer dans la salle. '
          'Utilise l\'adresse du compte Google de chaque étudiant.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'prenom.nom@gmail.com',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : _add,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 3),
          )
        else if (_error != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
              TextButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          )
        else if (_members.isEmpty)
          const Text(
            'Personne n\'est invité pour l\'instant.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          for (final member in _members)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
              ),
              title: Text(
                member.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: member.isCohost ? const Text('Co-organisateur') : null,
              trailing: IconButton(
                tooltip: 'Retirer',
                onPressed: _busy ? null : () => _remove(member),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ),
      ],
    );
  }
}
