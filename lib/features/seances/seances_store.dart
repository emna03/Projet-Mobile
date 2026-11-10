import 'package:flutter/material.dart';
import 'package:studymate/features/calendar/google_calendar_api.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/seance_user.dart';
import 'package:studymate/features/seances/seances_database.dart';

/// Séances de révision stored in SQLite through sqflite.
class SeancesStore extends ChangeNotifier {
  SeancesStore({
    SeancesDatabase? database,
    Future<SeanceUser> Function()? loadUser,
    GoogleCalendarApi? calendar,
  })  : _database = database ?? SeancesDatabase(),
        _loadUser = loadUser ?? loadCurrentSeanceUser,
        _calendar = calendar;

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
      await _dropCalendarEvent(removed);
      return true;
    } catch (error) {
      _error = '$error';
      notifyListeners();
      return false;
    }
  }
}
