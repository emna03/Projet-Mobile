import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/main.dart';

void main() {
  testWidgets('Séances screen lists revision sessions and filters them', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const StudyMateApp());

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
