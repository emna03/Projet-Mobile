import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studymate/features/groups/viewmodels/group_viewmodel.dart';
import 'package:studymate/main.dart';
import 'mocks/fake_group_repository.dart';

void main() {
  testWidgets('StudyMate renders Group Management screen with cards and controls',
      (WidgetTester tester) async {
    final fakeRepo = FakeGroupRepository();
    final viewModel = GroupViewModel(repository: fakeRepo);
    await viewModel.loadData();

    await tester.pumpWidget(MyApp(viewModel: viewModel));
    await tester.pumpAndSettle();

    // Verify header title and subtitle
    expect(find.text('Gestion des Groupes'), findsOneWidget);
    expect(
      find.text("Consultez, créez et gérez vos groupes d'étude"),
      findsOneWidget,
    );

    // Verify search bar, filter button and result counter
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(find.text('2 groupes trouvés'), findsOneWidget);
    expect(find.text('Licence 3'), findsWidgets);
    expect(find.text('Master 1'), findsWidgets);

    // Verify groups are rendered in the list
    expect(find.text('Spring Boot Masters'), findsOneWidget);
    expect(find.text('Docker & DevOps'), findsOneWidget);

    // Verify badges
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Privé'), findsOneWidget);

    // Verify action buttons on cards
    expect(find.text('Rejoindre le groupe'), findsOneWidget);
    expect(find.text('Gérer le groupe'), findsOneWidget);

    // Verify FAB
    expect(find.text('Nouveau groupe'), findsOneWidget);
  });

  testWidgets('Filter sheet applies filters, shows chips and updates counter',
      (WidgetTester tester) async {
    final viewModel = GroupViewModel(repository: FakeGroupRepository());
    await viewModel.loadData();

    await tester.pumpWidget(MyApp(viewModel: viewModel));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Filtrer les groupes'), findsOneWidget);

    await tester.tap(find.text('Publics'));
    await tester.pump();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    expect(find.text('1 groupe trouvé'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Publics'), findsOneWidget);
    expect(find.text('Docker & DevOps'), findsNothing);

    // Removing the chip clears the filter
    await tester.tap(find.byTooltip('Retirer le filtre'));
    await tester.pumpAndSettle();
    expect(find.text('2 groupes trouvés'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
  });
}
