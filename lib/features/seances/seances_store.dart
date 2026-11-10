import 'package:flutter/material.dart';
import 'package:studymate/features/availability/availability_models.dart';
import 'package:studymate/features/availability/demo_data.dart';
import 'package:studymate/features/calendar/google_calendar_api.dart';
import 'package:studymate/features/conflicts/schedule_conflicts.dart';
import 'package:studymate/features/notifications/seance_reminders.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/seance_user.dart';
import 'package:studymate/features/seances/seances_database.dart';

/// Séances de révision stored in SQLite through sqflite.
class SeancesStore extends ChangeNotifier {
  SeancesStore({
    SeancesDatabase? database,
    Future<SeanceUser> Function()? loadUser,
    GoogleCalendarApi? calendar,
    SeanceReminderScheduler? reminders,
    DateTime Function()? clock,
  })  : _database = database ?? SeancesDatabase(),
        _loadUser = loadUser ?? loadCurrentSeanceUser,
        _calendar = calendar,
        _reminders = reminders,
        _clock = clock ?? DateTime.now;

  /// Horloge remplaçable dans les tests.
  final DateTime Function() _clock;
  bool _disposed = false;

  Map<String, List<Seance>> _conflicts = const {};
  Map<String, List<String>> _unavailable = const {};
  int _conflictRequest = 0;

  /// Séances qui concernent l'utilisateur : proposées ou réservées.
  List<Seance> get mySeances =>
      List.unmodifiable(_items.where(canSyncCalendar));

  /// Séances à venir de l'utilisateur dont l'horaire chevauche celui de la
  /// séance [id]. Vide s'il n'y a pas de conflit.
  List<Seance> conflictsOf(String id) => _conflicts[id] ?? const [];

  /// Nombre de séances de l'utilisateur prises dans un conflit d'horaire.
  int get conflictCount => _conflicts.length;

  /// Participants qui ne sont pas libres à l'heure de la séance [id]
  /// (« toi » pour l'utilisateur). Renseigné pour les séances qu'il propose.
  List<String> unavailableFor(String id) => _unavailable[id] ?? const [];

  /// Conflits qu'aurait [candidate] avec les séances à venir de
  /// l'utilisateur, par exemple avant de la réserver ou de la publier.
  List<Seance> conflictsFor(Seance candidate) {
    final now = _clock();
    if (!seanceInterval(candidate).end.isAfter(now)) return const [];
    return conflictingSeances(
      candidate,
      _items.where(
        (seance) =>
            canSyncCalendar(seance) &&
            seanceInterval(seance).end.isAfter(now),
      ),
    );
  }

  Future<void> _conflictTask = Future<void>.value();

  /// Lance le recalcul sans faire attendre l'interface : les conflits entre
  /// séances sont à jour tout de suite, les indisponibilités (lues en base)
  /// arrivent juste après.
  void _scheduleConflictRefresh() {
    _conflictTask = _refreshConflicts();
  }

  /// Se termine quand le dernier recalcul des conflits est fini.
  Future<void> conflictsSettled() async {
    Future<void> task;
    do {
      task = _conflictTask;
      await task;
    } while (!identical(task, _conflictTask));
  }

  /// Recalcule les conflits d'horaires et les indisponibilités. Appelé
  /// après chaque changement des séances ou des disponibilités.
  Future<void> _refreshConflicts() async {
    final request = ++_conflictRequest;
    final now = _clock();
    _conflicts = detectSeanceConflicts(
      _items.where(canSyncCalendar),
      now: now,
    );
    final unavailable = <String, List<String>>{};
    try {
      for (final seance in List.of(_items)) {
        if (!isOwner(seance)) continue;
        if (!seanceInterval(seance).end.isAfter(now)) continue;
        final participants = await participantsFor(seance.id);
        // Sans autre participant, il n'y a personne avec qui s'accorder.
        if (participants.length < 2) continue;
        final missing = unavailableParticipants(seance, participants);
        if (missing.isNotEmpty) {
          unavailable[seance.id] = [
            for (final person in missing) person.isMe ? 'toi' : person.name,
          ];
        }
      }
    } catch (error) {
      debugPrint('Conflict detection error: $error');
    }
    if (request != _conflictRequest || _disposed) return;
    _unavailable = unavailable;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Rappels sur le téléphone. Null : aucune notification (tests).
  final SeanceReminderScheduler? _reminders;

  /// Prochaines séances de l'utilisateur (proposées ou réservées) avec l'état
  /// de leur rappel.
  List<SeanceAlert> alerts({DateTime? now}) {
    return upcomingAlerts(
      _items.where(canSyncCalendar),
      now: now ?? DateTime.now(),
    );
  }

  Future<bool> notificationsEnabled() async =>
      await _reminders?.notificationsEnabled() ?? false;

  Future<bool> enableNotifications() async {
    final granted = await _reminders?.enableNotifications() ?? false;
    if (granted) await _syncReminders();
    return granted;
  }

  Future<bool> sendTestNotification() async =>
      await _reminders?.sendTest() ?? false;

  /// Aligne les rappels sur les séances qui concernent l'utilisateur :
  /// celles qu'il propose et celles qu'il a réservées.
  Future<void> _syncReminders() async {
    _scheduleConflictRefresh();
    await _reminders?.sync(_items.where(canSyncCalendar));
  }

  final GoogleCalendarApi? _calendar;
  GoogleCalendarApi get _api => _calendar ?? googleCalendarApi;
  final Set<String> _calendarBusy = {};
  String? _calendarWarning;

  final Future<SeanceUser> Function() _loadUser;
  SeanceUser _user = SeanceUser.anonymous;

  final SeancesDatabase _database;
  final List<Seance> _items = [];
  SessionFormat? _format;
  bool _loading = true;
  String? _error;
  int _request = 0;

  bool get loading => _loading;
  String? get error => _error;
  SessionFormat? get format => _format;

  List<Seance> get items {
    final selected = _format;
    if (selected == null) return List.unmodifiable(_items);
    return List.unmodifiable(
      _items.where((seance) => seance.format == selected),
    );
  }

  Future<void> load() async {
    final request = ++_request;
    try {
      final currentUser = await _loadUser();
      final rows = await _database.readAll();
      if (request != _request) return;
      _user = currentUser;
      _items
        ..clear()
        ..addAll(rows);
      _error = null;
    } catch (error) {
      if (request != _request) return;
      _error = '$error';
    } finally {
      if (request == _request) {
        _loading = false;
        notifyListeners();
      }
    }
    if (request == _request && _error == null) await _syncReminders();
  }

  void setFormat(SessionFormat? format) {
    if (_format == format) return;
    _format = format;
    notifyListeners();
  }

  Future<void> toggleReservation(String id) async {
    final index = _items.indexWhere((seance) => seance.id == id);
    if (index == -1) return;
    final current = _items[index];
    late final Seance next;
    if (current.reserved) {
      next = current.copyWith(
        reserved: false,
        seatsLeft: current.seatsLeft + 1,
      );
    } else if (current.seatsLeft > 0) {
      next = current.copyWith(
        reserved: true,
        seatsLeft: current.seatsLeft - 1,
      );
    } else {
      return;
    }
    final dropEvent =
        current.reserved && current.inCalendar && !isOwner(current);
    final saved = dropEvent ? next.copyWith(clearCalendarEvent: true) : next;
    _items[index] = saved;
    notifyListeners();
    await _database.update(saved);
    await _syncReminders();
    if (dropEvent) await _dropCalendarEvent(current);
  }

  /// Message à afficher si la synchronisation Google Agenda a échoué en
  /// arrière-plan (modification ou suppression). Il n'est lu qu'une fois.
  String? takeCalendarWarning() {
    final warning = _calendarWarning;
    _calendarWarning = null;
    return warning;
  }

  bool isCalendarBusy(String id) => _calendarBusy.contains(id);

  /// Client Google Agenda utilisé pour lire et écrire l'agenda.
  GoogleCalendarApi get calendar => _api;

  /// Séances réservées par l'utilisateur, quel que soit le filtre affiché.
  List<Seance> get reservedSeances =>
      List.unmodifiable(_items.where((seance) => seance.reserved));

  /// Peut-on mettre cette séance dans l'agenda ? Oui si elle t'appartient ou
  /// si tu l'as réservée.
  bool canSyncCalendar(Seance seance) => isOwner(seance) || seance.reserved;

  /// Ajoute la séance à Google Agenda, ou l'en retire si elle y est déjà.
  Future<({bool ok, String message})> toggleCalendar(String id) async {
    final index = _items.indexWhere((seance) => seance.id == id);
    if (index == -1) return (ok: false, message: 'Séance introuvable.');
    final current = _items[index];
    if (!canSyncCalendar(current)) {
      return (
        ok: false,
        message: 'Réserve cette séance pour l\'ajouter à ton agenda.',
      );
    }
    if (!_calendarBusy.add(id)) {
      return (ok: false, message: 'Synchronisation déjà en cours.');
    }
    notifyListeners();
    try {
      final Seance next;
      final String message;
      if (current.inCalendar) {
        await _api.deleteEvent(current.calendarEventId!);
        next = current.copyWith(clearCalendarEvent: true);
        message = 'Séance retirée de Google Agenda.';
      } else {
        final eventId = await _api.upsertSeance(current);
        next = current.copyWith(calendarEventId: eventId);
        message = 'Séance ajoutée à Google Agenda.';
      }
      await _replaceCalendarState(next);
      return (ok: true, message: message);
    } on CalendarApiException catch (error) {
      return (ok: false, message: error.message);
    } finally {
      _calendarBusy.remove(id);
      notifyListeners();
    }
  }

  /// Garde le nouvel identifiant d'événement sans écraser le reste de la
  /// séance, qui a pu changer pendant l'appel réseau.
  Future<void> _replaceCalendarState(Seance next) async {
    final index = _items.indexWhere((seance) => seance.id == next.id);
    if (index == -1) return;
    final latest = _items[index].copyWith(
      calendarEventId: next.calendarEventId,
      clearCalendarEvent: !next.inCalendar,
    );
    _items[index] = latest;
    notifyListeners();
    await _database.update(latest);
  }

  Future<void> _dropCalendarEvent(Seance seance) async {
    if (!seance.inCalendar) return;
    try {
      await _api.deleteEvent(seance.calendarEventId!);
    } on CalendarApiException catch (error) {
      _calendarWarning =
          'Google Agenda n\'a pas pu retirer l\'événement : ${error.message}';
    }
  }

  Future<void> _refreshCalendarEvent(Seance seance) async {
    if (!seance.inCalendar) return;
    try {
      final eventId = await _api.upsertSeance(
        seance,
        eventId: seance.calendarEventId,
      );
      if (eventId != seance.calendarEventId) {
        await _replaceCalendarState(seance.copyWith(calendarEventId: eventId));
      }
    } on CalendarApiException catch (error) {
      _calendarWarning =
          'Séance enregistrée, mais Google Agenda n\'a pas été mis à jour : ${error.message}';
    }
  }

  /// Participants d'une séance : l'utilisateur connecté en premier, puis les
  /// personnes ajoutées, chacun avec ses disponibilités hebdomadaires.
  Future<List<Participant>> participantsFor(String seanceId) async {
    final me = Participant(
      id: user.id,
      name: user.displayName,
      isMe: true,
      windows: await _database.readAvailability(user.id),
    );
    return [me, ...await _database.readParticipants(seanceId)];
  }

  Future<void> saveAvailability(
    String userId,
    List<AvailabilityWindow> windows,
  ) async {
    await _database.replaceAvailability(userId, windows);
    _scheduleConflictRefresh();
  }

  Future<Participant> addParticipant(String seanceId, String name) async {
    final id = 'p-${DateTime.now().microsecondsSinceEpoch}';
    final clean = name.trim();
    await _database.addParticipant(seanceId, id, clean);
    _scheduleConflictRefresh();
    return Participant(id: id, name: clean);
  }

  Future<void> removeParticipant(String seanceId, String userId) async {
    await _database.removeParticipant(seanceId, userId);
    _scheduleConflictRefresh();
  }

  /// Y a-t-il des séances d'exemple dans la liste ?
  bool get hasDemoData => _items.any((seance) => isDemoId(seance.id));

  /// Ajoute les séances d'exemple (quatre séances à venir avec leurs
  /// participants fictifs). Faux si personne n'est connecté.
  Future<bool> loadDemoData({DateTime? now}) async {
    if (user.id.isEmpty) return false;
    await _database.insertDemo(
      buildDemoData(
        now: now ?? _clock(),
        ownerId: user.id,
        ownerName: user.displayName,
      ),
      ownerId: user.id,
    );
    await load();
    return true;
  }

  /// Supprime les séances d'exemple, et leurs événements Google Agenda.
  Future<void> clearDemoData() async {
    final demo = _items.where((seance) => isDemoId(seance.id)).toList();
    for (final seance in demo) {
      await _dropCalendarEvent(seance);
    }
    await _database.deleteDemo();
    await load();
  }

  SeanceUser get user => _user;

  bool isOwner(Seance seance) => user.owns(seance.ownerId);

  Future<bool> add(Seance seance) async {
    if (user.id.isEmpty) return false;
    final owned = seance.copyWith(ownerId: user.id);
    _request++;
    try {
      await _database.insert(owned);
      _items.insert(0, owned);
      _error = null;
      _loading = false;
      notifyListeners();
      await _syncReminders();
      return true;
    } catch (error) {
      _error = '$error';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(Seance seance) async {
    final index = _items.indexWhere((item) => item.id == seance.id);
    if (index == -1) return false;
    if (!isOwner(_items[index])) return false;
    final owned = seance.copyWith(ownerId: _items[index].ownerId);
    _request++;
    try {
      await _database.update(owned);
      _items[index] = owned;
      _error = null;
      notifyListeners();
      await _syncReminders();
      await _refreshCalendarEvent(owned);
      return true;
    } catch (error) {
      _error = '$error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(String id) async {
    final index = _items.indexWhere((seance) => seance.id == id);
    if (index == -1) return false;
    if (!isOwner(_items[index])) return false;
    _request++;
    try {
      final removed = _items[index];
      await _database.delete(id);
      _items.removeAt(index);
      _error = null;
      notifyListeners();
      await _syncReminders();
      await _dropCalendarEvent(removed);
      return true;
    } catch (error) {
      _error = '$error';
      notifyListeners();
      return false;
    }
  }
}
