import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/features/auth/current_user.dart';
import 'package:studymate/features/seances/seances_store.dart';
import 'package:studymate/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    AuthSession.instance.signIn(demoUsers.first);
    final path = p.join(await getDatabasesPath(), 'studymate_seances.db');
    await deleteDatabase(path);
  });

  testWidgets('Séances screen lists revision sessions and filters them', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const StudyMateApp());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tes prochaines séances'), findsOneWidget);
    expect(find.text('Connecté en tant que Alex Benali'), findsOneWidget);
    expect(find.text('Révisions Flutter & Dart'), findsOneWidget);
    expect(find.text('Ta séance'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    expect(find.text('Docker, de zéro à déployé'), findsOneWidget);
    expect(find.text('Construire une API Spring Boot'), findsOneWidget);
    expect(find.text('Réservé'), findsOneWidget);

    await tester.tap(find.text('Présentiel').first);
    await tester.pumpAndSettle();

    expect(find.text('Docker, de zéro à déployé'), findsNothing);
    expect(find.text('Construire une API Spring Boot'), findsOneWidget);

    await tester.tap(find.text('En ligne').first);
    await tester.pumpAndSettle();

    expect(find.text('Docker, de zéro à déployé'), findsOneWidget);
    expect(find.text('Construire une API Spring Boot'), findsNothing);

    await tester.ensureVisible(find.text('Réserver').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réserver').first);
    await tester.pump();

    expect(find.text('Réservé'), findsNWidgets(2));

    await tester.tap(find.text('Toutes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('AB'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sarah Ben Ali'));
    await tester.pumpAndSettle();

    expect(find.text('Connecté en tant que Sarah Ben Ali'), findsOneWidget);
    expect(find.text('Ta séance'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
  });

  test('a user cannot update or delete another student seance', () async {
    final store = SeancesStore();
    await store.load();

    final foreign = store.items.firstWhere((seance) => seance.id == 'docker');
    expect(store.isOwner(foreign), isFalse);
    expect(await store.delete(foreign.id), isFalse);
    expect(store.items.any((seance) => seance.id == 'docker'), isTrue);
    expect(await store.update(foreign.copyWith(title: 'Hacked')), isFalse);
    expect(
      store.items.firstWhere((seance) => seance.id == 'docker').title,
      'Docker, de zéro à déployé',
    );

    final mine = store.items.firstWhere((seance) => seance.id == 'flutter');
    expect(store.isOwner(mine), isTrue);
    expect(await store.update(mine.copyWith(title: 'Updated')), isTrue);
    expect(
      store.items.firstWhere((seance) => seance.id == 'flutter').title,
      'Updated',
    );
  });
}
