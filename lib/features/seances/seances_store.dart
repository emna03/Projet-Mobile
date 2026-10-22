import 'package:flutter/material.dart';
import 'package:studymate/features/auth/current_user.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/seances_database.dart';

/// Séances de révision stored in SQLite through sqflite.
class SeancesStore extends ChangeNotifier {
  SeancesStore({SeancesDatabase? database, AuthSession? session})
      : _database = database ?? SeancesDatabase(),
        _session = session ?? AuthSession.instance {
    _session.addListener(notifyListeners);
  }

  final AuthSession _session;

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
      final rows = await _database.readAll();
      if (request != _request) return;
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
    _items[index] = next;
    notifyListeners();
    await _database.update(next);
  }

  AppUser get user => _session.user;

  bool isOwner(Seance seance) => user.owns(seance.ownerId);

  @override
  void dispose() {
    _session.removeListener(notifyListeners);
    super.dispose();
  }

  Future<bool> add(Seance seance) async {
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
      await _database.delete(id);
      _items.removeAt(index);
      _error = null;
      notifyListeners();
      return true;
    } catch (error) {
      _error = '$error';
      notifyListeners();
      return false;
    }
  }
}
