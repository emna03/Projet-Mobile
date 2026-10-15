import 'package:flutter/material.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:studymate/features/seances/seances_database.dart';

/// Séances de révision stored in SQLite through sqflite.
class SeancesStore extends ChangeNotifier {
  SeancesStore({SeancesDatabase? database})
      : _database = database ?? SeancesDatabase();

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

  Future<void> add(Seance seance) async {
    _request++;
    try {
      await _database.insert(seance);
      _items.insert(0, seance);
      _error = null;
    } catch (error) {
      _error = '$error';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> update(Seance seance) async {
    final index = _items.indexWhere((item) => item.id == seance.id);
    if (index == -1) return;
    _request++;
    try {
      await _database.update(seance);
      _items[index] = seance;
      _error = null;
    } catch (error) {
      _error = '$error';
    }
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _request++;
    try {
      await _database.delete(id);
      _items.removeWhere((seance) => seance.id == id);
      _error = null;
    } catch (error) {
      _error = '$error';
    }
    notifyListeners();
  }
}
