import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studymate/features/meet/google_meet_api.dart';
import 'package:studymate/features/meet/meet_access_picker.dart';
import 'package:studymate/features/meet/meet_invitees.dart';
import 'package:studymate/features/meet/meet_space.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showMeetManager({
  required BuildContext context,
  required Seance seance,
  required Future<bool> Function(Seance seance) onSave,
  GoogleMeetApi? api,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return MeetManageSheet(
        seance: seance,
        onSave: onSave,
        api: api ?? googleMeetApi,
      );
    },
  );
}

class MeetManageSheet extends StatefulWidget {
  const MeetManageSheet({
    super.key,
    required this.seance,
    required this.onSave,
    required this.api,
  });

  final Seance seance;
  final Future<bool> Function(Seance seance) onSave;
  final GoogleMeetApi api;

  @override
  State<MeetManageSheet> createState() => _MeetManageSheetState();
}

class _MeetManageSheetState extends State<MeetManageSheet> {
  late Seance _seance;
  String? _conferenceRecord;
  String? _error;
  bool _loading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _seance = widget.seance;
    _refresh();
  }

  MeetAccess get _access => MeetAccessDetails.parse(_seance.meetAccess);

  bool get _canControl =>
      _seance.meetSpaceName != null && _seance.meetSpaceName!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final code = _seance.meetCode ?? meetingCodeFromLink(_seance.place);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom + keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Google Meet',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _seance.title,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (code != null) ...[
            Text(
              'Code $code',
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            _seance.place,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _StatusLine(
            loading: _loading,
            active: _conferenceRecord != null,
            known: _canControl && _error == null,
            error: _error,
          ),
          const SizedBox(height: 16),
          MeetAccessPicker(
            value: _access,
            enabled: _canControl && !_busy,
            onChanged: _changeAccess,
          ),
          if (_access == MeetAccess.restricted && _canControl)
            MeetInvitees(
              key: ValueKey(_seance.meetSpaceName),
              spaceName: _seance.meetSpaceName!,
              api: widget.api,
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _copy,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copier'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _open,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.video_call_outlined),
                  label: const Text('Rejoindre'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _busy || !_canControl ? null : _endConference,
              child: const Text('Terminer la réunion en cours'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _busy ? null : _replaceLink,
              child: const Text('Créer un nouveau lien'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    final resource =
        _seance.meetSpaceName ??
        _seance.meetCode ??
        meetingCodeFromLink(_seance.place);
    if (resource == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final space = await widget.api.getSpace(resource);
      final next = _apply(space);
      if (!mounted) return;
      setState(() {
        _seance = next;
        _conferenceRecord = space.conferenceRecord;
        _loading = false;
      });
      if (_changed(widget.seance, next)) {
        await widget.onSave(next);
      }
    } on MeetApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _changeAccess(MeetAccess access) async {
    final spaceName = _seance.meetSpaceName;
    if (spaceName == null || access == _access) return;
    setState(() => _busy = true);
    try {
      final space = await widget.api.updateAccess(spaceName, access);
      final next = _apply(space);
      final saved = await widget.onSave(next);
      if (!mounted) return;
      if (!saved) {
        _showMessage('Impossible d\'enregistrer ce réglage.');
        return;
      }
      setState(() => _seance = next);
    } on MeetApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endConference() async {
    final spaceName = _seance.meetSpaceName;
    if (spaceName == null) return;
    final confirmed = await _confirm(
      'Terminer la réunion',
      'Tout le monde sera déconnecté de cette salle. Le lien reste valable.',
      'Terminer',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.endActiveConference(spaceName);
      if (!mounted) return;
      setState(() => _conferenceRecord = null);
      _showMessage('Réunion terminée.');
    } on MeetApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replaceLink() async {
    final confirmed = await _confirm(
      'Nouveau lien Google Meet',
      'La séance utilisera une nouvelle salle. L\'ancien lien ne sera plus proposé.',
      'Créer',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final space = await widget.api.createSpace(access: _access);
      final next = _apply(space);
      final saved = await widget.onSave(next);
      if (!mounted) return;
      if (!saved) {
        _showMessage('Impossible d\'enregistrer le nouveau lien.');
        return;
      }
      setState(() {
        _seance = next;
        _conferenceRecord = null;
        _error = null;
      });
      _showMessage('Nouveau lien Google Meet créé.');
    } on MeetApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Seance _apply(MeetSpace space) {
    return Seance(
      id: _seance.id,
      ownerId: _seance.ownerId,
      subject: _seance.subject,
      title: _seance.title,
      host: _seance.host,
      date: _seance.date,
      start: _seance.start,
      end: _seance.end,
      format: _seance.format,
      place: space.meetingUri,
      seatsLeft: _seance.seatsLeft,
      reserved: _seance.reserved,
      free: _seance.free,
      priceLabel: _seance.priceLabel,
      meetSpaceName: space.name,
      meetCode: space.meetingCode,
      meetAccess: space.access.apiValue,
      calendarEventId: _seance.calendarEventId,
    );
  }

  bool _changed(Seance before, Seance after) {
    return before.place != after.place ||
        before.meetSpaceName != after.meetSpaceName ||
        before.meetCode != after.meetCode ||
        before.meetAccess != after.meetAccess;
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _seance.place.trim()));
    _showMessage('Lien Google Meet copié.');
  }

  Future<void> _open() async {
    final uri = Uri.tryParse(_seance.place.trim());
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showMessage('Impossible d\'ouvrir Google Meet.');
    }
  }

  Future<bool?> _confirm(String title, String message, String action) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.loading,
    required this.active,
    required this.known,
    required this.error,
  });

  final bool loading;
  final bool active;
  final bool known;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final message =
        error ??
        (loading
            ? 'Lecture de la salle...'
            : active
            ? 'Réunion en cours'
            : known
            ? 'Aucune réunion en cours'
            : 'Lien enregistré');
    final color = error != null
        ? const Color(0xFFB42318)
        : active
        ? AppColors.green
        : AppColors.muted;
    return Text(
      message,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
