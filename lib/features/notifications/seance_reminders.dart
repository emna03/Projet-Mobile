import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:studymate/features/calendar/google_calendar_api.dart';
import 'package:studymate/features/meet/meet_space.dart';
import 'package:studymate/features/seances/models/seance.dart';
import 'package:timezone/timezone.dart' as tz;

/// Délai entre le rappel et le début de la séance.
const reminderLead = Duration(minutes: 30);

/// Rappel à afficher avant une séance.
class SeanceReminder {
  const SeanceReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });

  /// Identifiant de notification, stable pour une séance donnée.
  final int id;
  final DateTime when;
  final String title;
  final String body;
}

/// Identifiant de notification d'une séance : FNV-1a sur 31 bits, pour
/// rester identique d'un lancement à l'autre (contrairement à `hashCode`).
int reminderId(String seanceId) {
  var hash = 0x811c9dc5;
  for (final unit in seanceId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Rappels à programmer pour [seances], du plus proche au plus lointain.
///
/// Une séance dont l'heure de rappel est déjà passée n'en reçoit pas : on ne
/// notifie pas en retard.
List<SeanceReminder> buildReminders(
  Iterable<Seance> seances, {
  required DateTime now,
  Duration lead = reminderLead,
}) {
  final reminders = <SeanceReminder>[];
  for (final seance in seances) {
    final when = seanceInterval(seance).start.subtract(lead);
    if (!when.isAfter(now)) continue;
    final place = seance.place.trim();
    final where = seance.isOnline
        ? (isGoogleMeetLink(place) ? 'Google Meet' : 'En ligne')
        : place;
    reminders.add(
      SeanceReminder(
        id: reminderId(seance.id),
        when: when,
        title: 'Séance dans ${lead.inMinutes} min : ${seance.title}',
        body: [
          '${formatSeanceTime(seance.start)} – ${formatSeanceTime(seance.end)}',
          'Avec ${seance.host}',
          if (where.isNotEmpty) where,
        ].join(' · '),
      ),
    );
  }
  reminders.sort((a, b) => a.when.compareTo(b.when));
  return reminders;
}

/// Une séance à venir avec l'état de son rappel.
class SeanceAlert {
  const SeanceAlert({
    required this.seance,
    required this.start,
    required this.remindAt,
    required this.sent,
  });

  final Seance seance;
  final DateTime start;
  final DateTime remindAt;

  /// Vrai quand l'heure du rappel est passée et que la séance n'a pas commencé.
  final bool sent;
}

/// Séances de [seances] qui n'ont pas encore commencé, de la plus proche à la
/// plus lointaine, avec l'heure de leur rappel.
List<SeanceAlert> upcomingAlerts(
  Iterable<Seance> seances, {
  required DateTime now,
  Duration lead = reminderLead,
}) {
  final alerts = <SeanceAlert>[];
  for (final seance in seances) {
    final start = seanceInterval(seance).start;
    if (!start.isAfter(now)) continue;
    final remindAt = start.subtract(lead);
    alerts.add(
      SeanceAlert(
        seance: seance,
        start: start,
        remindAt: remindAt,
        sent: !remindAt.isAfter(now),
      ),
    );
  }
  alerts.sort((a, b) => a.start.compareTo(b.start));
  return alerts;
}

/// Ce dont le store a besoin : garder les rappels alignés sur les séances.
abstract class SeanceReminderScheduler {
  Future<void> sync(Iterable<Seance> seances);

  /// Les notifications sont-elles autorisées sur cet appareil ?
  Future<bool> notificationsEnabled();

  /// Demande l'autorisation si besoin. Renvoie vrai si elle est accordée.
  Future<bool> enableNotifications();

  /// Affiche tout de suite une notification de test. Faux en cas d'échec.
  Future<bool> sendTest();
}

/// Accès aux notifications du téléphone, remplaçable dans les tests.
abstract class ReminderBackend {
  /// Faux si les notifications ne sont pas disponibles sur cet appareil.
  Future<bool> ensureReady();

  /// Demande à l'utilisateur d'autoriser les notifications, si nécessaire.
  Future<void> requestPermission();
  Future<bool> notificationsEnabled();
  Future<Set<int>> pendingIds();
  Future<void> schedule(SeanceReminder reminder);
  Future<void> cancel(int id);
  Future<void> showNow(String title, String body);
}

/// Programme un rappel par séance à venir et annule ceux devenus inutiles.
class SeanceReminders implements SeanceReminderScheduler {
  SeanceReminders({ReminderBackend? backend, DateTime Function()? clock})
    : _backend = backend ?? LocalNotificationsBackend(),
      _clock = clock ?? DateTime.now;

  final ReminderBackend _backend;
  final DateTime Function() _clock;
  Future<void> _queue = Future.value();
  bool _askedPermission = false;

  /// Les synchronisations s'exécutent l'une après l'autre : la dernière
  /// demandée a toujours le dernier mot.
  @override
  Future<void> sync(Iterable<Seance> seances) {
    final snapshot = List<Seance>.of(seances);
    return _queue = _queue.then((_) => _sync(snapshot));
  }

  @override
  Future<bool> notificationsEnabled() async {
    try {
      if (!await _backend.ensureReady()) return false;
      return await _backend.notificationsEnabled();
    } catch (error) {
      debugPrint('Seance reminders error: $error');
      return false;
    }
  }

  @override
  Future<bool> enableNotifications() async {
    try {
      if (!await _backend.ensureReady()) return false;
      _askedPermission = true;
      await _backend.requestPermission();
      return await _backend.notificationsEnabled();
    } catch (error) {
      debugPrint('Seance reminders error: $error');
      return false;
    }
  }

  @override
  Future<bool> sendTest() async {
    try {
      if (!await _backend.ensureReady()) return false;
      if (!await _backend.notificationsEnabled()) return false;
      await _backend.showNow(
        'Notification de test',
        'Les rappels de séances fonctionnent : tu seras prévenu '
        '${reminderLead.inMinutes} minutes avant chaque séance.',
      );
      return true;
    } catch (error) {
      debugPrint('Seance reminders error: $error');
      return false;
    }
  }

  Future<void> _sync(List<Seance> seances) async {
    try {
      if (!await _backend.ensureReady()) return;
      final reminders = buildReminders(seances, now: _clock());
      final wanted = {for (final reminder in reminders) reminder.id};

      for (final id in await _backend.pendingIds()) {
        if (!wanted.contains(id)) await _backend.cancel(id);
      }
      if (reminders.isEmpty) return;

      if (!_askedPermission) {
        _askedPermission = true;
        await _backend.requestPermission();
      }
      for (final reminder in reminders) {
        await _backend.schedule(reminder);
      }
    } catch (error) {
      // Un rappel manqué ne doit jamais bloquer la gestion des séances.
      debugPrint('Seance reminders error: $error');
    }
  }
}

/// Notifications locales Android via `flutter_local_notifications`.
class LocalNotificationsBackend implements ReminderBackend {
  LocalNotificationsBackend({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'seance_reminders',
      'Rappels de séances',
      channelDescription:
          'Rappel 30 minutes avant une séance de révision réservée ou proposée.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _ready;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> ensureReady() => _ready ??= _initialize();

  Future<bool> _initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    final ok = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    return ok ?? false;
  }

  @override
  Future<void> requestPermission() async {
    await _android?.requestNotificationsPermission();
  }

  @override
  Future<bool> notificationsEnabled() async {
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<void> showNow(String title, String body) {
    return _plugin.show(
      id: _testId,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }

  /// Identifiant réservé à la notification de test, à l'extrémité haute de la
  /// plage des identifiants de séance.
  static const _testId = 0x7ffffffe;

  @override
  Future<Set<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return {for (final request in pending) request.id};
  }

  @override
  Future<void> schedule(SeanceReminder reminder) async {
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      // Un instant en UTC : pas besoin de connaître le fuseau du téléphone.
      scheduledDate: tz.TZDateTime.from(reminder.when, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

final seanceReminders = SeanceReminders();
