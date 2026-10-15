import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:studymate/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
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

    await tester.ensureVisible(find.text('Réserver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réserver'));
    await tester.pump();

    expect(find.text('Réservé'), findsNWidgets(2));
  });
}
