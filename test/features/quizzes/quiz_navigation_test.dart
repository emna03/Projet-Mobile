import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/quizzes/quiz_demo_main.dart';
import 'package:studymate/features/quizzes/views/quiz_detail_page.dart';
import 'package:studymate/features/quizzes/views/quiz_history_page.dart';

void main() {
  testWidgets('la liste affiche les quiz fictifs', (tester) async {
    await tester.pumpWidget(const QuizDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('Mes Quiz'), findsOneWidget);
    expect(find.text('Quiz Java'), findsWidgets);
    expect(find.text('Quiz Spring Boot'), findsWidgets);
    expect(find.text('Créer un quiz'), findsOneWidget);
  });

  testWidgets('ouvre le détail depuis une carte', (tester) async {
    await tester.pumpWidget(const QuizDemoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voir le détail').first);
    await tester.pumpAndSettle();

    expect(find.byType(QuizDetailPage), findsOneWidget);
    expect(find.text('Commencer le quiz'), findsOneWidget);
  });

  testWidgets('ouvre l\'historique depuis la liste', (tester) async {
    await tester.pumpWidget(const QuizDemoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Historique'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizHistoryPage), findsOneWidget);
    expect(find.text('Historique des quiz'), findsOneWidget);
    expect(find.text('Quiz Java'), findsWidgets);
  });

  testWidgets('le parcours QCM ouvre la page des résultats', (tester) async {
    await tester.pumpWidget(const QuizDemoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voir le détail').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commencer le quiz'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Question 1'), findsOneWidget);

    for (var i = 0; i < 20; i++) {
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      if (find.text('Valider').evaluate().isNotEmpty) {
        await tester.tap(find.text('Valider'));
        await tester.pumpAndSettle();
      }
      if (find.text('Question suivante').evaluate().isNotEmpty) {
        await tester.tap(find.text('Question suivante'));
        await tester.pumpAndSettle();
        continue;
      }
      if (find.text('Voir les résultats').evaluate().isNotEmpty) {
        await tester.tap(find.text('Voir les résultats'));
        await tester.pumpAndSettle();
        break;
      }
    }

    expect(find.text('Félicitations'), findsOneWidget);
    expect(find.text('Refaire le quiz'), findsOneWidget);
    expect(find.text('Retour vers les quiz'), findsOneWidget);
    expect(find.textContaining('%'), findsWidgets);
  });

  testWidgets('crée un quiz depuis le formulaire', (tester) async {
    await tester.pumpWidget(const QuizDemoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Créer un quiz'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Quiz CRUD');
    await tester.enterText(fields.at(1), 'Quiz de test CRUD');
    await tester.enterText(fields.at(4), 'Quelle est la bonne réponse ?');
    await tester.enterText(fields.at(5), 'Oui');
    await tester.enterText(fields.at(6), 'Non');
    await tester.enterText(fields.at(7), 'Peut-être');
    await tester.enterText(fields.at(8), 'Jamais');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizDetailPage), findsOneWidget);
    expect(find.text('Quiz CRUD'), findsWidgets);
    expect(find.text('Commencer le quiz'), findsOneWidget);
  });

  testWidgets('le filtre Facile masque les quiz difficiles', (tester) async {
    await tester.pumpWidget(const QuizDemoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Facile').first);
    await tester.pumpAndSettle();

    expect(find.text('Quiz Java'), findsWidgets);
    expect(find.text('Quiz Microservices'), findsNothing);
  });
}
